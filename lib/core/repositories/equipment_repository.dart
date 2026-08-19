import '../database/app_database.dart';
import '../models/station_equipment_item.dart';

class EquipmentRepository {
  EquipmentRepository(this._db);

  final AppDatabase _db;

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
}
