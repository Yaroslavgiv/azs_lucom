import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../domain/maintenance_lifecycle.dart';
import '../domain/time_period.dart';
import '../models/maintenance_report.dart';
import '../models/station.dart';
import '../services/sync_change_publisher.dart';

class StationMaintenanceItem {
  StationMaintenanceItem({required this.station, this.dateDone, this.toType});

  final Station station;
  final String? dateDone;
  final String? toType;
}

class MaintenanceStatus {
  MaintenanceStatus({
    required this.status,
    this.toType,
    this.dateDone,
    this.assigneeName,
    this.dueDate,
    this.reviewComment,
  });

  final String status;
  final String? toType;
  final String? dateDone;
  final String? assigneeName;
  final String? dueDate;
  final String? reviewComment;

  bool get isDone => MaintenanceLifecycle.isAccepted(status);

  bool get isInReview => MaintenanceLifecycle.isAwaitingAcceptance(status);

  String get label => MaintenanceLifecycle.label(status);
}

class MaintenanceRepository {
  MaintenanceRepository(this._db, {SyncChangePublisher? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  String _currentMonth() => currentMonthIso();

  Future<MaintenanceStatus> getStatus(String stationNumber) async {
    final record = await getRecord(stationNumber);
    if (record == null) {
      return MaintenanceStatus(status: MaintenanceLifecycle.planned);
    }
    return MaintenanceStatus(
      status: record.status,
      toType: record.toType,
      dateDone: record.dateDone,
      assigneeName: record.assigneeName,
      dueDate: record.dueDate,
      reviewComment: record.reviewComment,
    );
  }

  Future<MaintenanceRecord?> getRecord(
    String stationNumber, {
    String? month,
  }) async {
    final period = month ?? _currentMonth();
    final rows = await _db.db.query(
      'maintenance',
      where: 'station_number = ? AND month = ?',
      whereArgs: [stationNumber, period],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MaintenanceRecord.fromMap(rows.first);
  }

  Future<Map<String, MaintenanceStatus>> getAllStatusesForCurrentMonth() async {
    final month = _currentMonth();
    final rows = await _db.db.query(
      'maintenance',
      where: 'month = ?',
      whereArgs: [month],
    );
    return {
      for (final r in rows)
        r['station_number'] as String: MaintenanceStatus(
          status: r['status'] as String,
          toType: r['to_type'] as String?,
          dateDone: r['date_done'] as String?,
          assigneeName: r['assignee_name'] as String?,
          dueDate: r['due_date'] as String?,
          reviewComment: r['review_comment'] as String?,
        ),
    };
  }

  Future<List<MaintenanceRecord>> listForMonth(String month) async {
    final rows = await _db.db.query(
      'maintenance',
      where: 'month = ?',
      whereArgs: [month],
    );
    return rows.map(MaintenanceRecord.fromMap).toList();
  }

  Future<List<MaintenanceRecord>> listAssignedTo(String userId) async {
    final rows = await _db.db.query(
      'maintenance',
      where: 'assignee_id = ? AND month = ?',
      whereArgs: [userId, _currentMonth()],
      orderBy: 'due_date',
    );
    return rows.map(MaintenanceRecord.fromMap).toList();
  }

  Future<Map<String, String?>?> getLastDone(String stationNumber) async {
    final rows = await _db.db.rawQuery(
      '''
      SELECT date_done, to_type FROM maintenance
      WHERE station_number = ? AND status IN (${MaintenanceLifecycle.sqlAcceptedIn})
      ORDER BY date_done DESC
      LIMIT 1
      ''',
      [stationNumber],
    );
    if (rows.isEmpty) return null;
    return {
      'date_done': rows.first['date_done'] as String?,
      'to_type': rows.first['to_type'] as String?,
    };
  }

  Future<void> assign({
    required String stationNumber,
    required String assigneeId,
    required String assigneeName,
    String? dueDate,
    String? actorId,
    String? month,
  }) async {
    final period = month ?? _currentMonth();
    final existing = await getRecord(stationNumber, month: period);
    final record = MaintenanceRecord(
      stationNumber: stationNumber,
      month: period,
      status: existing?.status == MaintenanceLifecycle.accepted
          ? existing!.status
          : MaintenanceLifecycle.planned,
      dateDone: existing?.dateDone,
      toType: existing?.toType,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      dueDate: dueDate,
      comment: existing?.comment,
      checklist: existing?.checklist ?? const [],
      photoUrls: existing?.photoUrls ?? const [],
      updatedBy: actorId,
      updatedAt: currentDateTimeIso(),
      submittedAt: existing?.submittedAt,
      reviewedBy: existing?.reviewedBy,
      reviewComment: existing?.reviewComment,
      version: (existing?.version ?? 0) + 1,
    );
    await _upsert(record);
  }

  Future<void> submitForReview(
    String stationNumber, {
    String? toType,
    String? comment,
    List<MaintenanceChecklistItem> checklist = const [],
    List<String> photoUrls = const [],
    String? actorId,
    String? actorName,
  }) async {
    final month = _currentMonth();
    final existing = await getRecord(stationNumber, month: month);
    final record = MaintenanceRecord(
      stationNumber: stationNumber,
      month: month,
      status: MaintenanceLifecycle.inReview,
      dateDone: currentDateTimeIso(),
      toType: toType ?? existing?.toType,
      assigneeId: actorId ?? existing?.assigneeId,
      assigneeName: actorName ?? existing?.assigneeName,
      dueDate: existing?.dueDate,
      comment: comment ?? existing?.comment,
      checklist: checklist,
      photoUrls: photoUrls,
      updatedBy: actorId,
      updatedAt: currentDateTimeIso(),
      submittedAt: currentDateTimeIso(),
      reviewedBy: existing?.reviewedBy,
      reviewComment: existing?.reviewComment,
      version: (existing?.version ?? 0) + 1,
    );
    await _upsert(record);
  }

  Future<void> applyReview({
    required String stationNumber,
    required String status,
    String? comment,
    String? reviewerId,
    String? month,
  }) async {
    final period = month ?? _currentMonth();
    final existing = await getRecord(stationNumber, month: period);
    if (existing == null) return;
    final record = MaintenanceRecord(
      stationNumber: stationNumber,
      month: period,
      status: status,
      dateDone: existing.dateDone ?? currentDateTimeIso(),
      toType: existing.toType,
      assigneeId: existing.assigneeId,
      assigneeName: existing.assigneeName,
      dueDate: existing.dueDate,
      comment: existing.comment,
      checklist: existing.checklist,
      photoUrls: existing.photoUrls,
      updatedBy: reviewerId,
      updatedAt: currentDateTimeIso(),
      submittedAt: existing.submittedAt,
      reviewedBy: reviewerId,
      reviewComment: comment,
      version: existing.version + 1,
    );
    await _upsert(record);
  }

  /// Совместимость со старым UI: отправка на приёмку, не финальный статус.
  Future<void> markDone(String stationNumber, {String? toType}) {
    return submitForReview(stationNumber, toType: toType);
  }

  Future<List<StationMaintenanceItem>> getStationsByRegion({
    required String region,
    required bool done,
  }) async {
    final month = _currentMonth();
    final rows = done
        ? await _db.db.rawQuery(
            '''
            SELECT s.number, s.name, s.address, s.region, s.lat, s.lon, s.geocode_status,
              m.date_done, m.to_type
            FROM stations s
            INNER JOIN maintenance m
              ON s.number = m.station_number AND m.month = ?
             AND m.status IN (${MaintenanceLifecycle.sqlAcceptedIn})
            WHERE s.region = ?
            ORDER BY CAST(s.number AS INTEGER)
          ''',
            [month, region],
          )
        : await _db.db.rawQuery(
            '''
            SELECT s.number, s.name, s.address, s.region, s.lat, s.lon, s.geocode_status,
              m.date_done, m.to_type
            FROM stations s
            LEFT JOIN maintenance m
              ON s.number = m.station_number AND m.month = ?
            WHERE s.region = ?
              AND (m.status IS NULL OR m.status NOT IN (${MaintenanceLifecycle.sqlAcceptedIn}))
            ORDER BY CAST(s.number AS INTEGER)
          ''',
            [month, region],
          );

    return rows.map((row) {
      return StationMaintenanceItem(
        station: Station.fromMap(row),
        dateDone: row['date_done'] as String?,
        toType: row['to_type'] as String?,
      );
    }).toList();
  }

  Future<void> _upsert(MaintenanceRecord record) async {
    await _db.db.insert(
      'maintenance',
      record.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.maintenance,
        localPk: record.localPk,
      );
    }
  }
}
