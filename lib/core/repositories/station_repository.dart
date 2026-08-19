import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/station.dart';
import '../services/sync_change_publisher.dart';

class StationRepository {
  StationRepository(this._db, {SyncChangePublisher? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  Future<List<Station>> getByRegion(String region) async {
    final rows = await _db.db.query(
      'stations',
      where: 'region = ?',
      whereArgs: [region],
      orderBy: 'CAST(number AS INTEGER)',
    );
    return rows.map(Station.fromMap).toList();
  }

  Future<List<Station>> getAllWithCoordinates() async {
    final rows = await _db.db.query(
      'stations',
      where: 'lat IS NOT NULL AND lon IS NOT NULL',
      orderBy: 'region, CAST(number AS INTEGER)',
    );
    return rows.map(Station.fromMap).toList();
  }

  Future<List<Station>> getNeedingGeocode() async {
    final rows = await _db.db.query(
      'stations',
      where: 'geocode_status = 0 OR lat IS NULL',
      orderBy: 'region, CAST(number AS INTEGER)',
    );
    return rows.map(Station.fromMap).toList();
  }

  Future<Station?> getByNumber(String number) async {
    final rows = await _db.db.query(
      'stations',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Station.fromMap(rows.first);
  }

  Future<void> upsert(Station station) async {
    await _db.db.insert(
      'stations',
      station.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.stations,
        localPk: station.number,
      );
    }
  }

  Future<void> updateGeocode({
    required String number,
    required String name,
    required String address,
    required double lat,
    required double lon,
    int status = 1,
  }) async {
    await _db.db.update(
      'stations',
      {
        'name': name,
        'address': address,
        'lat': lat,
        'lon': lon,
        'geocode_status': status,
      },
      where: 'number = ?',
      whereArgs: [number],
    );
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.stations,
        localPk: number,
      );
    }
  }

  Future<void> markGeocodeFailed(String number) async {
    await _db.db.update(
      'stations',
      {'geocode_status': -1},
      where: 'number = ?',
      whereArgs: [number],
    );
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.stations,
        localPk: number,
      );
    }
  }
}
