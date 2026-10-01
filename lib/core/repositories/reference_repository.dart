import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../services/ids.dart';

class ReferenceRepository {
  const ReferenceRepository(this._db);

  final AppDatabase _db;

  Future<void> upsert({
    required String kind,
    required String code,
    required String name,
    int sortOrder = 0,
  }) async {
    await _db.db.insert('reference_values', {
      'id': '$kind:$code',
      'kind': kind,
      'code': code,
      'name': name,
      'active': 1,
      'sort_order': sortOrder,
      'version': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> archive(String id) async {
    await _db.db.update(
      'reference_values',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.db.insert('audit_events', {
      'id': newUuid(),
      'actor_id': 'admin',
      'entity_type': 'reference',
      'entity_id': id,
      'action': 'archive',
      'previous_value': 'active',
      'new_value': 'archived',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
