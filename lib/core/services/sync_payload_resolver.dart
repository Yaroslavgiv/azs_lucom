import '../database/app_database.dart';
import 'sync_change_publisher.dart';

class SyncPayloadResolver {
  const SyncPayloadResolver(this._database);

  final AppDatabase _database;

  Future<Map<String, Object?>> resolve({
    required String entity,
    required String localPk,
  }) async {
    switch (entity) {
      case SyncEntity.stations:
        return _stationPayload(localPk);
      case SyncEntity.requests:
        return _requestPayload(int.parse(localPk));
      case SyncEntity.maintenance:
        return _maintenancePayload(localPk);
      case SyncEntity.stationEquipment:
        return _equipmentPayload(int.parse(localPk));
      case SyncEntity.stationInfo:
        return _stationInfoPayload(localPk);
      case SyncEntity.defectActs:
        return _defectActPayload(int.parse(localPk));
      default:
        return {};
    }
  }

  Future<Map<String, Object?>> _requestPayload(int id) async {
    final rows = await _database.db.query(
      'requests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final row = rows.first;
    return {
      'station_number': row['station_number'],
      'type': row['type'],
      'request_type': row['request_type'],
      'description': row['description'],
      'date_created': row['date_created'],
      'status': row['status'],
      'close_comment': row['close_comment'],
      'close_date': row['close_date'],
    };
  }

  Future<Map<String, Object?>> _maintenancePayload(String localPk) async {
    final separator = localPk.indexOf('_');
    if (separator < 1 || separator == localPk.length - 1) return {};
    final rows = await _database.db.query(
      'maintenance',
      where: 'station_number = ? AND month = ?',
      whereArgs: [
        localPk.substring(0, separator),
        localPk.substring(separator + 1),
      ],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final row = rows.first;
    return {
      'station_number': row['station_number'],
      'month': row['month'],
      'status': row['status'],
      'date_done': row['date_done'],
      'to_type': row['to_type'],
    };
  }

  Future<Map<String, Object?>> _equipmentPayload(int id) async {
    final rows = await _database.db.query(
      'station_equipment',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final row = rows.first;
    return {
      'station_number': row['station_number'],
      'category': row['category'],
      'description': row['description'],
    };
  }

  Future<Map<String, Object?>> _stationInfoPayload(
    String stationNumber,
  ) async {
    final rows = await _database.db.query(
      'station_info',
      where: 'station_number = ?',
      whereArgs: [stationNumber],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    return {'manager_contact': rows.first['manager_contact']};
  }

  Future<Map<String, Object?>> _defectActPayload(int id) async {
    final rows = await _database.db.query(
      'defect_acts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    return Map<String, Object?>.from(rows.first)..remove('id');
  }

  Future<Map<String, Object?>> _stationPayload(String number) async {
    final rows = await _database.db.query(
      'stations',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final row = rows.first;
    return {
      'name': row['name'],
      'address': row['address'],
      'lat': row['lat'],
      'lon': row['lon'],
      'region': row['region'],
      'geocode_status': row['geocode_status'],
    };
  }
}
