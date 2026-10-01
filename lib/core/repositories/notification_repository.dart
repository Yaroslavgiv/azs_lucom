import '../database/app_database.dart';

class NotificationRepository {
  const NotificationRepository(this._db);

  final AppDatabase _db;

  Future<List<Map<String, Object?>>> listFor(String recipientId) {
    return _db.db.query(
      'notifications',
      where: 'recipient_id = ?',
      whereArgs: [recipientId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> markRead(String id) async {
    await _db.db.update(
      'notifications',
      {'read_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
