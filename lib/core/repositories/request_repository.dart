import '../database/app_database.dart';
import '../domain/request_status.dart';
import '../domain/time_period.dart';
import '../models/request_item.dart';
import '../services/sync_change_publisher.dart';

class RequestQuery {
  const RequestQuery({
    this.region,
    this.status,
    this.assigneeId,
    this.stationNumber,
    this.fromDate,
    this.toDate,
    this.activeOnly = false,
  });

  final String? region;
  final String? status;
  final String? assigneeId;
  final String? stationNumber;
  final String? fromDate;
  final String? toDate;
  final bool activeOnly;
}

class RequestRepository {
  RequestRepository(this._db, {SyncChangePublisher? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  Future<List<RequestItem>> getOpenByStation(String stationNumber) async {
    final rows = await _db.db.rawQuery(
      '''
      SELECT * FROM requests
      WHERE station_number = ?
        AND status IN (${RequestStatus.sqlActiveIn})
      ORDER BY date_created DESC, id DESC
      ''',
      [stationNumber],
    );
    return rows.map(RequestItem.fromMap).toList();
  }

  Future<List<RequestItem>> getClosedByStation(String stationNumber) async {
    final rows = await _db.db.query(
      'requests',
      where: "station_number = ? AND status IN ('done','closed')",
      whereArgs: [stationNumber],
      orderBy: 'close_date DESC, id DESC',
    );
    return rows.map(RequestItem.fromMap).toList();
  }

  Future<List<RequestItem>> getAssignedTo(String userId) async {
    final rows = await _db.db.rawQuery(
      '''
      SELECT * FROM requests
      WHERE assignee_id = ?
        AND status IN (${RequestStatus.sqlActiveIn})
      ORDER BY due_date IS NULL, due_date, date_created DESC
      ''',
      [userId],
    );
    return rows.map(RequestItem.fromMap).toList();
  }

  Future<List<RequestItem>> list(RequestQuery query) async {
    final where = <String>[];
    final args = <Object>[];
    if (query.stationNumber != null) {
      where.add('r.station_number = ?');
      args.add(query.stationNumber!);
    }
    if (query.assigneeId != null) {
      where.add('r.assignee_id = ?');
      args.add(query.assigneeId!);
    }
    if (query.status != null) {
      where.add('r.status = ?');
      args.add(query.status!);
    } else if (query.activeOnly) {
      where.add('r.status IN (${RequestStatus.sqlActiveIn})');
    }
    if (query.region != null) {
      where.add('s.region = ?');
      args.add(query.region!);
    }
    if (query.fromDate != null) {
      where.add('r.date_created >= ?');
      args.add(query.fromDate!);
    }
    if (query.toDate != null) {
      where.add('r.date_created <= ?');
      args.add(query.toDate!);
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await _db.db.rawQuery('''
      SELECT r.* FROM requests r
      JOIN stations s ON s.number = r.station_number
      $clause
      ORDER BY r.date_created DESC, r.id DESC
    ''', args);
    return rows.map(RequestItem.fromMap).toList();
  }

  Future<int> add({
    required String stationNumber,
    required String requestType,
    required String description,
    String? createdBy,
  }) async {
    final now = currentDateIso();
    final id = await _db.db.insert('requests', {
      'station_number': stationNumber,
      'type': 'НЗ',
      'request_type': requestType,
      'description': description,
      'date_created': now,
      'status': RequestStatus.created,
      'updated_by': createdBy,
      'updated_at': currentDateTimeIso(),
      'version': 1,
    });
    await _publish('$id');
    return id;
  }

  Future<void> updateDescription(int id, String description) async {
    await _db.db.update(
      'requests',
      {'description': description, 'updated_at': currentDateTimeIso()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _publish('$id');
  }

  Future<void> assign({
    required int id,
    required String assigneeId,
    required String assigneeName,
    required String dueDate,
    String? actorId,
  }) async {
    await _db.db.update(
      'requests',
      {
        'assignee_id': assigneeId,
        'assignee_name': assigneeName,
        'due_date': dueDate,
        'status': RequestStatus.assigned,
        'updated_by': actorId,
        'updated_at': currentDateTimeIso(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _publish('$id');
  }

  Future<void> setStatus(int id, String status, {String? actorId}) async {
    await _db.db.update(
      'requests',
      {
        'status': status,
        'updated_by': actorId,
        'updated_at': currentDateTimeIso(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _publish('$id');
  }

  Future<void> close(int id, {String comment = '', String? actorId}) async {
    await _db.db.update(
      'requests',
      {
        'status': RequestStatus.done,
        'close_comment': comment,
        'close_date': currentDateTimeIso(),
        'updated_by': actorId,
        'updated_at': currentDateTimeIso(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _publish('$id');
  }

  Future<void> _publish(String localPk) async {
    final sync = _sync;
    if (sync == null) return;
    await sync.publishUpsert(entity: SyncEntity.requests, localPk: localPk);
  }
}
