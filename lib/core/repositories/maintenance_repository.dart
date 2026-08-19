import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/station.dart';
import '../services/sync_service.dart';

class StationMaintenanceItem {
  StationMaintenanceItem({required this.station, this.dateDone, this.toType});

  final Station station;
  final String? dateDone;
  final String? toType;
}

class MaintenanceStatus {
  MaintenanceStatus({required this.status, this.toType, this.dateDone});

  final String status;
  final String? toType;
  final String? dateDone;

  bool get isDone => status == 'done';
}

class MaintenanceRepository {
  MaintenanceRepository(this._db, {SyncService? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncService? _sync;

  String _currentMonth() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  Future<MaintenanceStatus> getStatus(String stationNumber) async {
    final month = _currentMonth();
    final rows = await _db.db.query(
      'maintenance',
      where: 'station_number = ? AND month = ?',
      whereArgs: [stationNumber, month],
      limit: 1,
    );
    if (rows.isEmpty) {
      return MaintenanceStatus(status: 'pending');
    }
    final r = rows.first;
    return MaintenanceStatus(
      status: r['status'] as String,
      toType: r['to_type'] as String?,
      dateDone: r['date_done'] as String?,
    );
  }

  /// Все статусы ТО за текущий месяц (один запрос вместо N).
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
        ),
    };
  }

  Future<Map<String, String?>?> getLastDone(String stationNumber) async {
    final rows = await _db.db.query(
      'maintenance',
      where: "station_number = ? AND status = 'done'",
      whereArgs: [stationNumber],
      orderBy: 'date_done DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return {
      'date_done': rows.first['date_done'] as String?,
      'to_type': rows.first['to_type'] as String?,
    };
  }

  Future<void> markDone(String stationNumber, {String? toType}) async {
    final month = _currentMonth();
    final now = DateTime.now();
    final dateDone =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await _db.db.insert('maintenance', {
      'station_number': stationNumber,
      'month': month,
      'status': 'done',
      'date_done': dateDone,
      'to_type': toType,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final sync = _sync;
    if (sync != null) {
      final localPk = '${stationNumber}_$month';
      await sync.enqueue(
        entity: SyncService.entityMaintenance,
        localPk: localPk,
        op: 'upsert',
        payload: await sync.maintenancePayload(stationNumber, month),
      );
    }
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
              ON s.number = m.station_number AND m.month = ? AND m.status = 'done'
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
            WHERE s.region = ? AND (m.status IS NULL OR m.status != 'done')
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
}
