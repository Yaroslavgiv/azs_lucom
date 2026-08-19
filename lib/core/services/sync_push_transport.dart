import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_change_publisher.dart';
import 'sync_map_store.dart';
import 'sync_queue_store.dart';

abstract interface class SyncPushTransport {
  Future<void> push(SyncQueueItem item);
}

class FirestoreSyncPushTransport implements SyncPushTransport {
  const FirestoreSyncPushTransport(this._firestore, this._mapStore);

  final FirebaseFirestore _firestore;
  final SyncMapStore _mapStore;

  @override
  Future<void> push(SyncQueueItem item) async {
    if (item.operation == 'delete') {
      await _delete(item);
      return;
    }
    await _upsert(item);
  }

  Future<void> _delete(SyncQueueItem item) async {
    final remoteId =
        await _mapStore.findRemoteId(item.entity, item.localPk) ??
        (_usesLocalIdAsRemoteId(item.entity) ? item.localPk : null);
    if (remoteId == null) return;

    await _firestore.collection(item.entity).doc(remoteId).delete();
    await _mapStore.remove(item.entity, item.localPk);
  }

  Future<void> _upsert(SyncQueueItem item) async {
    final data = Map<String, Object?>.from(item.payload);
    data['updated_at'] = FieldValue.serverTimestamp();

    final mappedRemoteId = await _mapStore.findRemoteId(
      item.entity,
      item.localPk,
    );
    final remoteId =
        mappedRemoteId ??
        (_usesLocalIdAsRemoteId(item.entity) ? item.localPk : null);
    final collection = _firestore.collection(item.entity);

    if (remoteId == null) {
      final document = await collection.add(data);
      await _saveMapping(item, document.id);
      return;
    }

    await collection.doc(remoteId).set(data, SetOptions(merge: true));
    await _saveMapping(item, remoteId);
  }

  bool _usesLocalIdAsRemoteId(String entity) {
    return entity == SyncEntity.stations ||
        entity == SyncEntity.stationInfo ||
        entity == SyncEntity.maintenance;
  }

  Future<void> _saveMapping(SyncQueueItem item, String remoteId) {
    return _mapStore.put(
      entity: item.entity,
      localId: item.localPk,
      remoteId: remoteId,
    );
  }
}
