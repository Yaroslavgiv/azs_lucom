import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class SyncMapStore {
  const SyncMapStore(this._database);

  final AppDatabase _database;

  Future<String?> findRemoteId(String entity, String localId) async {
    final rows = await _database.db.query(
      'sync_map',
      columns: ['remote_id'],
      where: 'entity = ? AND local_id = ?',
      whereArgs: [entity, localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['remote_id'] as String?;
  }

  Future<String?> findLocalId(String entity, String remoteId) async {
    final rows = await _database.db.query(
      'sync_map',
      columns: ['local_id'],
      where: 'entity = ? AND remote_id = ?',
      whereArgs: [entity, remoteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['local_id'] as String?;
  }

  Future<void> put({
    required String entity,
    required String localId,
    required String remoteId,
  }) async {
    await _database.db.insert('sync_map', {
      'entity': entity,
      'local_id': localId,
      'remote_id': remoteId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String entity, String localId) async {
    await _database.db.delete(
      'sync_map',
      where: 'entity = ? AND local_id = ?',
      whereArgs: [entity, localId],
    );
  }

  Future<void> clearEntity(String entity) async {
    await _database.db.delete(
      'sync_map',
      where: 'entity = ?',
      whereArgs: [entity],
    );
  }
}
