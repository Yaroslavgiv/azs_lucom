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
    this.attempts = 0,
    this.lastError,
    this.state = 'pending',
    this.idempotencyKey,
    this.dependsOn,
    this.nextAttemptAt,
  });

  final int id;
  final String entity;
  final String localPk;
  final String operation;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final String state;
  final String? idempotencyKey;
  final String? dependsOn;
  final DateTime? nextAttemptAt;
}

class SyncQueueStore {
  const SyncQueueStore(this._database);

  static const maxAttempts = 5;

  final AppDatabase _database;

  Future<void> put({
    required String entity,
    required String localPk,
    required String operation,
    Map<String, Object?> payload = const {},
    String? dependsOn,
    String? idempotencyKey,
  }) async {
    await _database.db.insert('sync_queue', {
      'entity': entity,
      'local_pk': localPk,
      'op': operation,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'state': 'pending',
      'idempotency_key': idempotencyKey,
      'depends_on': dependsOn,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SyncQueueItem>> nextBatch({int limit = 25}) async {
    final rows = await _database.db.rawQuery(
      '''
      SELECT *
      FROM sync_queue
      WHERE state != 'error'
        AND (
          depends_on IS NULL
          OR depends_on = ''
          OR NOT EXISTS (
            SELECT 1 FROM sync_queue parent
            WHERE parent.entity || ':' || parent.local_pk = sync_queue.depends_on
          )
        )
      ORDER BY id ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> remove(int id) async {
    await _database.db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> recordFailure(int id, String error) async {
    final rows = await _database.db.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final attempts = ((rows.first['attempts'] as int?) ?? 0) + 1;
    final exhausted = attempts >= maxAttempts;
    final delaySeconds = exhausted ? 0 : 1 << attempts;
    await _database.db.update(
      'sync_queue',
      {
        'attempts': attempts,
        'last_error': error,
        'state': exhausted ? 'error' : 'pending',
        'next_attempt_at': exhausted
            ? null
            : DateTime.now()
                  .add(Duration(seconds: delaySeconds))
                  .toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countByState(String state) async {
    final rows = await _database.db.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_queue WHERE state = ?',
      [state],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  SyncQueueItem _fromRow(Map<String, Object?> row) {
    final nextAttempt = row['next_attempt_at'] as String?;
    return SyncQueueItem(
      id: row['id']! as int,
      entity: row['entity']! as String,
      localPk: row['local_pk']! as String,
      operation: row['op']! as String,
      payload: Map<String, Object?>.from(
        jsonDecode(row['payload_json']! as String) as Map,
      ),
      createdAt: DateTime.parse(row['created_at']! as String),
      attempts: (row['attempts'] as int?) ?? 0,
      lastError: row['last_error'] as String?,
      state: (row['state'] as String?) ?? 'pending',
      idempotencyKey: row['idempotency_key'] as String?,
      dependsOn: row['depends_on'] as String?,
      nextAttemptAt: nextAttempt == null ? null : DateTime.parse(nextAttempt),
    );
  }
}
