import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'sync_logger.dart';

enum SyncStatus { idle, syncing, offline, error, synced }

/// Bidirectional sync between sqflite cache and Cloud Firestore.
class SyncService {
  SyncService(
    this._db, {
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
    SyncLogger logger = const DeveloperSyncLogger(),
  }) : _fs = firestore ?? FirebaseFirestore.instance,
       _connectivity = connectivity ?? Connectivity(),
       _logger = logger;

  final AppDatabase _db;
  final FirebaseFirestore _fs;
  final Connectivity _connectivity;
  final SyncLogger _logger;

  bool _flushing = false;
  bool _pulling = false;

  static const entityStations = 'stations';
  static const entityRequests = 'requests';
  static const entityMaintenance = 'maintenance';
  static const entityStationEquipment = 'station_equipment';
  static const entityStationInfo = 'station_info';
  static const entityDefectActs = 'defect_acts';
  static const entityEquipmentOrderExports = 'equipment_order_exports';

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
    await _db.db.insert('sync_queue', {
      'entity': entity,
      'local_pk': localPk,
      'op': op,
      'payload_json': jsonEncode(payload ?? {}),
      'created_at': DateTime.now().toIso8601String(),
    });
    unawaited(flushQueue());
  }

  Future<String?> getRemoteId(String entity, String localId) async {
    final rows = await _db.db.query(
      'sync_map',
      where: 'entity = ? AND local_id = ?',
      whereArgs: [entity, localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['remote_id'] as String?;
  }

  Future<String?> getLocalId(String entity, String remoteId) async {
    final rows = await _db.db.query(
      'sync_map',
      where: 'entity = ? AND remote_id = ?',
      whereArgs: [entity, remoteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['local_id'] as String?;
  }

  Future<void> _putMap(String entity, String localId, String remoteId) async {
    await _db.db.insert('sync_map', {
      'entity': entity,
      'local_id': localId,
      'remote_id': remoteId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> flushQueue() async {
    if (_flushing) return;
    if (!await isOnline()) return;
    _flushing = true;
    try {
      while (true) {
        final rows = await _db.db.query(
          'sync_queue',
          orderBy: 'id ASC',
          limit: 25,
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          final id = row['id'] as int;
          final entity = row['entity'] as String;
          final localPk = row['local_pk'] as String;
          final op = row['op'] as String;
          final payload = Map<String, Object?>.from(
            jsonDecode(row['payload_json'] as String) as Map,
          );
          try {
            await _pushOne(
              entity: entity,
              localPk: localPk,
              op: op,
              payload: payload,
            );
            await _db.db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
          } catch (error, stackTrace) {
            // Keep item in queue; stop flush to avoid tight failure loop.
            _logger.error('Failed to flush $entity/$localPk', error, stackTrace);
            return;
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _pushOne({
    required String entity,
    required String localPk,
    required String op,
    required Map<String, Object?> payload,
  }) async {
    final col = _fs.collection(entity);
    if (op == 'delete') {
      final remoteId =
          await getRemoteId(entity, localPk) ??
          (entity == entityStations ||
                  entity == entityStationInfo ||
                  entity == entityMaintenance
              ? localPk
              : null);
      if (remoteId != null) {
        await col.doc(remoteId).delete();
        await _db.db.delete(
          'sync_map',
          where: 'entity = ? AND local_id = ?',
          whereArgs: [entity, localPk],
        );
      }
      return;
    }

    final data = Map<String, Object?>.from(payload);
    data['updated_at'] = FieldValue.serverTimestamp();

    String? remoteId = await getRemoteId(entity, localPk);
    if (remoteId == null) {
      if (entity == entityStations || entity == entityStationInfo) {
        remoteId = localPk;
      } else if (entity == entityMaintenance) {
        remoteId = localPk; // station_month
      }
    }

    if (remoteId == null) {
      final doc = await col.add(data);
      remoteId = doc.id;
      await _putMap(entity, localPk, remoteId);
    } else {
      await col.doc(remoteId).set(data, SetOptions(merge: true));
      await _putMap(entity, localPk, remoteId);
    }
  }

  /// Full pull from Firestore into sqflite cache.
  Future<SyncStatus> pullAll() async {
    if (_pulling) return SyncStatus.syncing;
    if (!await isOnline()) return SyncStatus.offline;
    _pulling = true;
    try {
      await flushQueue();
      await _pullStations();
      await _pullStationInfo();
      await _pullMaintenance();
      await _replaceMappedCollection(
        entity: entityRequests,
        table: 'requests',
        buildRow: (remoteId, data) => {
          'station_number': data['station_number'],
          'type': data['type'] ?? 'НЗ',
          'request_type': data['request_type'] ?? '',
          'description': data['description'] ?? '',
          'date_created': data['date_created'] ?? '',
          'status': data['status'] ?? 'open',
          'close_comment': data['close_comment'],
          'close_date': data['close_date'],
        },
      );
      await _replaceMappedCollection(
        entity: entityStationEquipment,
        table: 'station_equipment',
        buildRow: (remoteId, data) => {
          'station_number': data['station_number'],
          'category': data['category'] ?? '',
          'description': data['description'] ?? '',
        },
      );
      await _replaceMappedCollection(
        entity: entityDefectActs,
        table: 'defect_acts',
        buildRow: (remoteId, data) => {
          'station_number': data['station_number'],
          'created_at': data['created_at'] ?? '',
          'equipment_category': data['equipment_category'] ?? '',
          'equipment_name': data['equipment_name'] ?? '',
          'assessment': data['assessment'] ?? '',
          'declared_fault': data['declared_fault'] ?? '',
          'faulty': data['faulty'] ?? '',
          'conclusion': data['conclusion'] ?? '',
          'rendered_text': data['rendered_text'] ?? '',
        },
      );
      await _replaceMappedCollection(
        entity: entityEquipmentOrderExports,
        table: 'equipment_order_exports',
        buildRow: (remoteId, data) => {
          'region': data['region'] ?? '',
          'export_date': data['export_date'] ?? '',
          'request_id': data['request_id'] ?? 0,
        },
      );

      await _db.setMeta('last_pull_at', DateTime.now().toIso8601String());
      return SyncStatus.synced;
    } catch (error, stackTrace) {
      _logger.error('Failed to pull Firestore data', error, stackTrace);
      return SyncStatus.error;
    } finally {
      _pulling = false;
    }
  }

  Future<void> _pullStations() async {
    final snap = await _fs.collection(entityStations).get();
    for (final doc in snap.docs) {
      final d = doc.data();
      await _db.db.insert('stations', {
        'number': doc.id,
        'name': d['name'] ?? '',
        'address': d['address'] ?? '',
        'lat': d['lat'],
        'lon': d['lon'],
        'region': d['region'] ?? '',
        'geocode_status': (d['geocode_status'] as num?)?.toInt() ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _putMap(entityStations, doc.id, doc.id);
    }
  }

  Future<void> _pullStationInfo() async {
    final snap = await _fs.collection(entityStationInfo).get();
    for (final doc in snap.docs) {
      final d = doc.data();
      await _db.db.insert('station_info', {
        'station_number': doc.id,
        'manager_contact': d['manager_contact'] ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _putMap(entityStationInfo, doc.id, doc.id);
    }
  }

  Future<void> _pullMaintenance() async {
    final snap = await _fs.collection(entityMaintenance).get();
    // Пустой cloud не должен затирать локальный seed/кеш.
    if (snap.docs.isEmpty) return;

    await _db.db.delete('maintenance');
    await _db.db.delete(
      'sync_map',
      where: 'entity = ?',
      whereArgs: [entityMaintenance],
    );
    for (final doc in snap.docs) {
      final d = doc.data();
      final station =
          (d['station_number'] as String?) ?? doc.id.split('_').first;
      final month =
          (d['month'] as String?) ??
          (doc.id.contains('_')
              ? doc.id.substring(doc.id.indexOf('_') + 1)
              : '');
      if (station.isEmpty || month.isEmpty) continue;
      final localPk = '${station}_$month';
      await _db.db.insert('maintenance', {
        'station_number': station,
        'month': month,
        'status': d['status'] ?? 'pending',
        'date_done': d['date_done'],
        'to_type': d['to_type'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _putMap(entityMaintenance, localPk, doc.id);
    }
  }

  Future<void> _replaceMappedCollection({
    required String entity,
    required String table,
    required Map<String, Object?> Function(
      String remoteId,
      Map<String, dynamic> data,
    )
    buildRow,
  }) async {
    final snap = await _fs.collection(entity).get();
    // Пустой cloud не должен затирать локальный seed/кеш.
    if (snap.docs.isEmpty) return;

    await _db.db.delete(table);
    await _db.db.delete('sync_map', where: 'entity = ?', whereArgs: [entity]);
    for (final doc in snap.docs) {
      final row = buildRow(doc.id, doc.data());
      final newId = await _db.db.insert(table, row);
      await _putMap(entity, '$newId', doc.id);
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

    if (await _isCollectionEmpty(entityStations)) {
      final stations = await _db.db.query('stations');
      for (final s in stations) {
        final number = s['number'] as String;
        await _fs.collection(entityStations).doc(number).set({
          'name': s['name'] ?? '',
          'address': s['address'] ?? '',
          'lat': s['lat'],
          'lon': s['lon'],
          'region': s['region'] ?? '',
          'geocode_status': s['geocode_status'] ?? 0,
          'updated_at': FieldValue.serverTimestamp(),
        });
        await _putMap(entityStations, number, number);
      }
      uploaded = stations.isNotEmpty || uploaded;
    }

    if (await _isCollectionEmpty(entityStationInfo)) {
      final infos = await _db.db.query('station_info');
      for (final row in infos) {
        final sn = row['station_number'] as String;
        await _fs.collection(entityStationInfo).doc(sn).set({
          'manager_contact': row['manager_contact'] ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        });
        await _putMap(entityStationInfo, sn, sn);
      }
      uploaded = infos.isNotEmpty || uploaded;
    }

    if (await _isCollectionEmpty(entityMaintenance)) {
      final maint = await _db.db.query('maintenance');
      for (final row in maint) {
        final sn = row['station_number'] as String;
        final month = row['month'] as String;
        final id = '${sn}_$month';
        await _fs.collection(entityMaintenance).doc(id).set({
          'station_number': sn,
          'month': month,
          'status': row['status'] ?? 'pending',
          'date_done': row['date_done'],
          'to_type': row['to_type'],
          'updated_at': FieldValue.serverTimestamp(),
        });
        await _putMap(entityMaintenance, id, id);
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
        await uploadMappedIfEmpty(entityRequests, 'requests') || uploaded;
    uploaded =
        await uploadMappedIfEmpty(
          entityStationEquipment,
          'station_equipment',
        ) ||
        uploaded;
    uploaded =
        await uploadMappedIfEmpty(entityDefectActs, 'defect_acts') || uploaded;
    uploaded =
        await uploadMappedIfEmpty(
          entityEquipmentOrderExports,
          'equipment_order_exports',
        ) ||
        uploaded;

    if (uploaded) {
      await _db.setMeta('cloud_seeded', '1');
    }
    return uploaded;
  }

  Future<Map<String, Object?>> requestPayload(int id) async {
    final rows = await _db.db.query(
      'requests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final r = rows.first;
    return {
      'station_number': r['station_number'],
      'type': r['type'],
      'request_type': r['request_type'],
      'description': r['description'],
      'date_created': r['date_created'],
      'status': r['status'],
      'close_comment': r['close_comment'],
      'close_date': r['close_date'],
    };
  }

  Future<Map<String, Object?>> maintenancePayload(
    String stationNumber,
    String month,
  ) async {
    final rows = await _db.db.query(
      'maintenance',
      where: 'station_number = ? AND month = ?',
      whereArgs: [stationNumber, month],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final r = rows.first;
    return {
      'station_number': r['station_number'],
      'month': r['month'],
      'status': r['status'],
      'date_done': r['date_done'],
      'to_type': r['to_type'],
    };
  }

  Future<Map<String, Object?>> equipmentPayload(int id) async {
    final rows = await _db.db.query(
      'station_equipment',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final r = rows.first;
    return {
      'station_number': r['station_number'],
      'category': r['category'],
      'description': r['description'],
    };
  }

  Future<Map<String, Object?>> defectActPayload(int id) async {
    final rows = await _db.db.query(
      'defect_acts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final r = Map<String, Object?>.from(rows.first)..remove('id');
    return r;
  }

  Future<Map<String, Object?>> stationPayload(String number) async {
    final rows = await _db.db.query(
      'stations',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final r = rows.first;
    return {
      'name': r['name'],
      'address': r['address'],
      'lat': r['lat'],
      'lon': r['lon'],
      'region': r['region'],
      'geocode_status': r['geocode_status'],
    };
  }
}
