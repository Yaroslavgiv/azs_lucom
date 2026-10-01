import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../database/app_database.dart';
import 'sync_logger.dart';

class AttachmentUploadService {
  AttachmentUploadService(
    this._database, {
    FirebaseStorage? storage,
    SyncLogger logger = const DeveloperSyncLogger(),
  }) : _storage = storage ?? FirebaseStorage.instance,
       _logger = logger;

  final AppDatabase _database;
  final FirebaseStorage _storage;
  final SyncLogger _logger;

  Future<void> uploadPending() async {
    final rows = await _database.db.query(
      'attachments',
      where: "upload_state = 'pending' AND local_path IS NOT NULL",
    );
    for (final row in rows) {
      final localPath = row['local_path'] as String?;
      if (localPath == null) continue;
      final file = File(localPath);
      if (!file.existsSync()) continue;
      final storagePath =
          'attachments/${row['entity_type']}/${row['entity_id']}/${row['id']}';
      try {
        await _storage.ref(storagePath).putFile(file);
        await _database.db.update(
          'attachments',
          {'upload_state': 'uploaded', 'storage_path': storagePath},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (error, stackTrace) {
        _logger.error(
          'Failed to upload attachment ${row['id']}',
          error,
          stackTrace,
        );
        await _database.db.update(
          'attachments',
          {'upload_state': 'error'},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }
}
