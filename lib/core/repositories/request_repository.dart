import '../database/app_database.dart';
import '../models/request_item.dart';
import '../services/sync_change_publisher.dart';

class RequestRepository {
  RequestRepository(this._db, {SyncChangePublisher? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  Future<List<RequestItem>> getOpenByStation(String stationNumber) async {
    final rows = await _db.db.query(
      'requests',
      where: "station_number = ? AND status = 'open'",
      whereArgs: [stationNumber],
      orderBy: 'date_created DESC, id DESC',
    );
    return rows.map(RequestItem.fromMap).toList();
  }

  Future<int> add({
    required String stationNumber,
    required String requestType,
    required String description,
  }) async {
    final now = DateTime.now().toIso8601String().substring(0, 10);
    final id = await _db.db.insert('requests', {
      'station_number': stationNumber,
      'type': 'НЗ',
      'request_type': requestType,
      'description': description,
      'date_created': now,
      'status': 'open',
    });
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.requests,
        localPk: '$id',
      );
    }
    return id;
  }

  Future<void> updateDescription(int id, String description) async {
    await _db.db.update(
      'requests',
      {'description': description},
      where: 'id = ?',
      whereArgs: [id],
    );
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.requests,
        localPk: '$id',
      );
    }
  }

  Future<void> close(int id, {String comment = ''}) async {
    final now = DateTime.now();
    final closeDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await _db.db.update(
      'requests',
      {'status': 'closed', 'close_comment': comment, 'close_date': closeDate},
      where: 'id = ?',
      whereArgs: [id],
    );
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.requests,
        localPk: '$id',
      );
    }
  }
}
