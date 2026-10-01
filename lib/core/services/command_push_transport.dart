import 'package:cloud_functions/cloud_functions.dart';

import 'sync_change_publisher.dart';
import 'sync_map_store.dart';
import 'sync_push_transport.dart';
import 'sync_queue_store.dart';

class FirebaseWorkCommandGateway {
  const FirebaseWorkCommandGateway(this._functions);

  final FirebaseFunctions _functions;

  Future<void> call(Map<String, Object?> payload) async {
    await _functions.httpsCallable('applyWorkCommand').call(payload);
  }
}

class CommandAwarePushTransport implements SyncPushTransport {
  const CommandAwarePushTransport({
    required SyncPushTransport inner,
    required FirebaseWorkCommandGateway commands,
    required SyncMapStore mapStore,
  }) : _inner = inner,
       _commands = commands,
       _mapStore = mapStore;

  final SyncPushTransport _inner;
  final FirebaseWorkCommandGateway _commands;
  final SyncMapStore _mapStore;

  @override
  Future<void> push(SyncQueueItem item) async {
    if (item.entity != SyncEntity.workCommands) {
      await _inner.push(item);
      return;
    }
    final targetEntity = item.payload['target_entity'] as String?;
    final targetLocalId = item.payload['target_local_id'] as String?;
    final remoteId = targetEntity == null || targetLocalId == null
        ? null
        : await _mapStore.findRemoteId(targetEntity, targetLocalId);
    if (remoteId == null) {
      throw StateError('Родительская запись ещё не синхронизирована');
    }
    final payload = Map<String, Object?>.from(item.payload);
    payload['remote_id'] = remoteId;
    await _commands.call(payload);
  }
}
