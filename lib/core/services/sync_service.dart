import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../database/app_database.dart';
import 'firestore_pull_service.dart';
import 'sync_change_publisher.dart';
import 'sync_logger.dart';
import 'sync_map_store.dart';
import 'sync_payload_resolver.dart';
import 'sync_push_transport.dart';
import 'sync_queue_flusher.dart';
import 'sync_queue_store.dart';

enum SyncStatus { idle, syncing, offline, error, synced }

/// Bidirectional sync between sqflite cache and Cloud Firestore.
class SyncService implements SyncChangePublisher {
  SyncService(
    AppDatabase database, {
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
    SyncLogger logger = const DeveloperSyncLogger(),
    SyncQueueStore? queueStore,
    SyncPayloadResolver? payloadResolver,
    SyncMapStore? mapStore,
    SyncPushTransport? pushTransport,
    SyncQueueFlusher? queueFlusher,
    FirestorePullService? pullService,
  }) : _db = database,
       _fs = firestore ?? FirebaseFirestore.instance,
       _connectivity = connectivity ?? Connectivity(),
       _logger = logger,
       _queueStore = queueStore ?? SyncQueueStore(database),
       _payloadResolver = payloadResolver ?? SyncPayloadResolver(database),
       _mapStore = mapStore ?? SyncMapStore(database),
       _queueFlusher =
           queueFlusher ??
           SyncQueueFlusher(
             queueStore: queueStore ?? SyncQueueStore(database),
             pushTransport:
                 pushTransport ??
                 FirestoreSyncPushTransport(
                   firestore ?? FirebaseFirestore.instance,
                   mapStore ?? SyncMapStore(database),
                 ),
             logger: logger,
           ),
       _pullService =
           pullService ??
           FirestorePullService(
             database,
             firestore ?? FirebaseFirestore.instance,
             mapStore ?? SyncMapStore(database),
           );

  final AppDatabase _db;
  final FirebaseFirestore _fs;
  final Connectivity _connectivity;
  final SyncLogger _logger;
  final SyncQueueStore _queueStore;
  final SyncPayloadResolver _payloadResolver;
  final SyncMapStore _mapStore;
  final SyncQueueFlusher _queueFlusher;
  final FirestorePullService _pullService;

  bool _pulling = false;

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> enqueue({
    required String entity,
    required String localPk,
    required String op,
    Map<String, Object?>? payload,
  }) async {
    await _queueStore.put(
      entity: entity,
      localPk: localPk,
      operation: op,
      payload: payload ?? const {},
    );
    unawaited(flushQueue());
  }

  @override
  Future<void> publishUpsert({
    required String entity,
    required String localPk,
  }) async {
    await publishUpsertPayload(
      entity: entity,
      localPk: localPk,
      payload: await _payloadResolver.resolve(entity: entity, localPk: localPk),
    );
  }

  @override
  Future<void> publishUpsertPayload({
    required String entity,
    required String localPk,
    required Map<String, Object?> payload,
  }) {
    return enqueue(
      entity: entity,
      localPk: localPk,
      op: 'upsert',
      payload: payload,
    );
  }

  @override
  Future<void> publishDelete({
    required String entity,
    required String localPk,
  }) {
    return enqueue(entity: entity, localPk: localPk, op: 'delete');
  }

  Future<void> _putMap(String entity, String localId, String remoteId) async {
    await _mapStore.put(entity: entity, localId: localId, remoteId: remoteId);
  }

  Future<void> flushQueue() async {
    if (!await isOnline()) return;
    await _queueFlusher.flush();
  }

  /// Full pull from Firestore into sqflite cache.
  Future<SyncStatus> pullAll() async {
    if (_pulling) return SyncStatus.syncing;
    if (!await isOnline()) return SyncStatus.offline;
    _pulling = true;
    try {
      await flushQueue();
      await _pullService.pullAll();
      return SyncStatus.synced;
    } catch (error, stackTrace) {
      _logger.error('Failed to pull Firestore data', error, stackTrace);
      return SyncStatus.error;
    } finally {
      _pulling = false;
    }
  }

  Future<bool> _isCollectionEmpty(String entity) async {
    final snap = await _fs.collection(entity).limit(1).get();
    return snap.docs.isEmpty;
  }

  /// Upload local cache into any Firestore collections that are still empty.
  Future<bool> seedCloudIfEmpty() async {
    if (!await isOnline()) return false;

    var uploaded = false;

    if (await _isCollectionEmpty(SyncEntity.stations)) {
      final stations = await _db.db.query('stations');
      for (final s in stations) {
        final number = s['number'] as String;
        await _fs.collection(SyncEntity.stations).doc(number).set({
          'name': s['name'] ?? '',
          'address': s['address'] ?? '',
          'lat': s['lat'],
          'lon': s['lon'],
          'region': s['region'] ?? '',
          'geocode_status': s['geocode_status'] ?? 0,
          'updated_at': FieldValue.serverTimestamp(),
        });
        await _putMap(SyncEntity.stations, number, number);
      }
      uploaded = stations.isNotEmpty || uploaded;
    }

    if (await _isCollectionEmpty(SyncEntity.stationInfo)) {
      final infos = await _db.db.query('station_info');
      for (final row in infos) {
        final sn = row['station_number'] as String;
        await _fs.collection(SyncEntity.stationInfo).doc(sn).set({
          'manager_contact': row['manager_contact'] ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        });
        await _putMap(SyncEntity.stationInfo, sn, sn);
      }
      uploaded = infos.isNotEmpty || uploaded;
    }

    if (await _isCollectionEmpty(SyncEntity.maintenance)) {
      final maint = await _db.db.query('maintenance');
      for (final row in maint) {
        final sn = row['station_number'] as String;
        final month = row['month'] as String;
        final id = '${sn}_$month';
        await _fs.collection(SyncEntity.maintenance).doc(id).set({
          'station_number': sn,
          'month': month,
          'status': row['status'] ?? 'pending',
          'date_done': row['date_done'],
          'to_type': row['to_type'],
          'updated_at': FieldValue.serverTimestamp(),
        });
        await _putMap(SyncEntity.maintenance, id, id);
      }
      uploaded = maint.isNotEmpty || uploaded;
    }

    Future<bool> uploadMappedIfEmpty(String entity, String table) async {
      if (!await _isCollectionEmpty(entity)) return false;
      final rows = await _db.db.query(table);
      for (final row in rows) {
        final localId = '${row['id']}';
        final data = Map<String, Object?>.from(row)..remove('id');
        data['updated_at'] = FieldValue.serverTimestamp();
        final doc = await _fs.collection(entity).add(data);
        await _putMap(entity, localId, doc.id);
      }
      return rows.isNotEmpty;
    }

    uploaded =
        await uploadMappedIfEmpty(SyncEntity.requests, 'requests') || uploaded;
    uploaded =
        await uploadMappedIfEmpty(
          SyncEntity.stationEquipment,
          'station_equipment',
        ) ||
        uploaded;
    uploaded =
        await uploadMappedIfEmpty(SyncEntity.defectActs, 'defect_acts') ||
        uploaded;
    uploaded =
        await uploadMappedIfEmpty(
          SyncEntity.equipmentOrderExports,
          'equipment_order_exports',
        ) ||
        uploaded;

    if (uploaded) {
      await _db.setMeta('cloud_seeded', '1');
    }
    return uploaded;
  }
}
