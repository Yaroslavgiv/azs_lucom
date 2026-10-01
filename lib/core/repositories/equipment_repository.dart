import '../database/app_database.dart';
import '../models/station_equipment_item.dart';
import '../services/sync_change_publisher.dart';

class EquipmentRepository {
  EquipmentRepository(this._db, {SyncChangePublisher? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  Future<List<StationEquipmentItem>> listForStation(
    String stationNumber,
  ) async {
    final rows = await _db.db.query(
      'station_equipment',
      where: 'station_number = ?',
      whereArgs: [stationNumber],
      orderBy: 'category, description',
    );
    return rows.map(StationEquipmentItem.fromMap).toList();
  }

  Future<void> updatePassport({
    required int id,
    required String model,
    required int quantity,
    String? serialNumber,
    String condition = '',
    String? authorId,
  }) async {
    final rows = await _db.db.query(
      'station_equipment',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final current = rows.first;
    final now = DateTime.now().toIso8601String();
    await _db.db.update(
      'station_equipment',
      {
        'model': model,
        'quantity': quantity,
        'serial_number': serialNumber,
        'condition': condition,
        'updated_by': authorId,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    const fields = {
      'model': 'model',
      'quantity': 'quantity',
      'serial_number': 'serial_number',
      'condition': 'condition',
    };
    final next = {
      'model': model,
      'quantity': '$quantity',
      'serial_number': serialNumber ?? '',
      'condition': condition,
    };
    for (final entry in fields.entries) {
      final previous = '${current[entry.value] ?? ''}';
      if (previous == next[entry.key]) continue;
      await _db.db.insert('equipment_history', {
        'equipment_id': id,
        'field_name': entry.key,
        'previous_value': previous,
        'new_value': next[entry.key],
        'author_id': authorId,
        'changed_at': now,
      });
    }
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.stationEquipment,
        localPk: '$id',
      );
    }
  }

  Future<List<Map<String, Object?>>> history(int equipmentId) {
    return _db.db.query(
      'equipment_history',
      where: 'equipment_id = ?',
      whereArgs: [equipmentId],
      orderBy: 'changed_at, id',
    );
  }
}
