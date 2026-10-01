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
      case SyncEntity.contractRules:
        return _contractRulePayload(localPk);
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
      'uuid': row['uuid'],
      'category': row['category'],
      'author_id': row['author_id'],
      'assignee_id': row['assignee_id'],
      'due_at': row['due_at'],
      'result_text': row['result_text'],
      'critical': row['critical'],
      'revision': row['revision'],
      'workflow_status': row['workflow_status'],
      'requires_review': row['requires_review'],
      'source': row['source'],
      'management_id': row['management_id'],
      'department_id': row['department_id'],
      'crew_id': row['crew_id'],
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
      'workflow_status': row['workflow_status'],
      'assignee_id': row['assignee_id'],
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

  Future<Map<String, Object?>> _stationInfoPayload(String stationNumber) async {
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

  Future<Map<String, Object?>> _contractRulePayload(String id) async {
    final rows = await _database.db.query(
      'contract_rules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final row = rows.first;
    return {
      'category': row['category'],
      'duration_hours': row['duration_hours'],
      'requires_review': row['requires_review'],
      'effective_from': row['effective_from'],
      'version': row['version'],
      'active': row['active'],
    };
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
      'management_id': row['management_id'],
      'department_id': row['department_id'],
      'crew_id': row['crew_id'],
      'specialist_id': row['specialist_id'],
      'active': row['active'],
      'created_by': row['created_by'],
      'created_at': row['created_at'],
      'input_method': row['input_method'],
    };
  }
}
