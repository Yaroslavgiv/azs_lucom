import '../database/app_database.dart';
import '../services/ids.dart';
import '../services/sync_change_publisher.dart';

class AttachmentRepository {
  AttachmentRepository(this._db, {SyncChangePublisher? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  Future<String> addLocal({
    required String entityType,
    required String entityId,
    required String fileName,
    required String localPath,
    String mimeType = 'image/jpeg',
    int sizeBytes = 0,
    String? authorId,
    String? dependsOn,
  }) async {
    final id = newUuid();
    final createdAt = DateTime.now().toIso8601String();
    await _db.db.insert('attachments', {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'local_path': localPath,
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'author_id': authorId,
      'created_at': createdAt,
      'upload_state': 'pending',
    });
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsertPayload(
        entity: SyncEntity.attachments,
        localPk: id,
        dependsOn: dependsOn,
        payload: {
          'entity_type': entityType,
          'entity_id': entityId,
          'file_name': fileName,
          'mime_type': mimeType,
          'size_bytes': sizeBytes,
          'author_id': authorId,
          'created_at': createdAt,
          'upload_state': 'pending',
          'local_path': localPath,
        },
      );
    }
    return id;
  }

  Future<List<Map<String, Object?>>> listFor(
    String entityType,
    String entityId,
  ) {
    return _db.db.query(
      'attachments',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'created_at',
    );
  }
}
