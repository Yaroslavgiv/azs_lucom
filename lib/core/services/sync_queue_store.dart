import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.entity,
    required this.localPk,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  final int id;
  final String entity;
  final String localPk;
  final String operation;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}

class SyncQueueStore {
  const SyncQueueStore(this._database);

  final AppDatabase _database;

  Future<void> put({
    required String entity,
    required String localPk,
    required String operation,
    Map<String, Object?> payload = const {},
  }) async {
    await _database.db.insert(
      'sync_queue',
      {
        'entity': entity,
        'local_pk': localPk,
        'op': operation,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncQueueItem>> nextBatch({int limit = 25}) async {
    final rows = await _database.db.query(
      'sync_queue',
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> remove(int id) async {
    await _database.db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  SyncQueueItem _fromRow(Map<String, Object?> row) {
    return SyncQueueItem(
      id: row['id']! as int,
      entity: row['entity']! as String,
      localPk: row['local_pk']! as String,
      operation: row['op']! as String,
      payload: Map<String, Object?>.from(
        jsonDecode(row['payload_json']! as String) as Map,
      ),
      createdAt: DateTime.parse(row['created_at']! as String),
    );
  }
}
