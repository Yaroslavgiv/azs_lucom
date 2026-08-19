import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../database/app_database.dart';
import 'firestore_cloud_seeder.dart';
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
    FirestoreCloudSeeder? cloudSeeder,
  }) : _connectivity = connectivity ?? Connectivity(),
       _logger = logger,
       _queueStore = queueStore ?? SyncQueueStore(database),
       _payloadResolver = payloadResolver ?? SyncPayloadResolver(database),
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
           ),
       _cloudSeeder =
           cloudSeeder ??
           FirestoreCloudSeeder(
             database,
             firestore ?? FirebaseFirestore.instance,
             mapStore ?? SyncMapStore(database),
           );

  final Connectivity _connectivity;
  final SyncLogger _logger;
  final SyncQueueStore _queueStore;
  final SyncPayloadResolver _payloadResolver;
  final SyncQueueFlusher _queueFlusher;
  final FirestorePullService _pullService;
  final FirestoreCloudSeeder _cloudSeeder;

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

  /// Upload local cache into any Firestore collections that are still empty.
  Future<bool> seedCloudIfEmpty() async {
    if (!await isOnline()) return false;
    return _cloudSeeder.seedEmptyCollections();
  }
}
