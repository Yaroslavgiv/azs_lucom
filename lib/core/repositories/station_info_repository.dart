import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../services/sync_change_publisher.dart';

class EquipmentItem {
  EquipmentItem({
    required this.id,
    required this.stationNumber,
    required this.category,
    required this.description,
  });

  final int id;
  final String stationNumber;
  final String category;
  final String description;

  factory EquipmentItem.fromMap(Map<String, Object?> m) => EquipmentItem(
    id: m['id'] as int,
    stationNumber: m['station_number'] as String,
    category: m['category'] as String,
    description: (m['description'] as String?) ?? '',
  );
}

class StationInfoRepository {
  StationInfoRepository(this._db, {SyncChangePublisher? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;

  Future<String> getManagerContact(String stationNumber) async {
    final rows = await _db.db.query(
      'station_info',
      where: 'station_number = ?',
      whereArgs: [stationNumber],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return (rows.first['manager_contact'] as String?) ?? '';
  }

  Future<void> setManagerContact(String stationNumber, String contact) async {
    await _db.db.insert('station_info', {
      'station_number': stationNumber,
      'manager_contact': contact,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsertPayload(
        entity: SyncEntity.stationInfo,
        localPk: stationNumber,
        payload: {'manager_contact': contact},
      );
    }
  }

  Future<List<EquipmentItem>> getEquipment(
    String stationNumber,
    String category,
  ) async {
    final rows = await _db.db.query(
      'station_equipment',
      where: 'station_number = ? AND category = ?',
      whereArgs: [stationNumber, category],
      orderBy: 'id',
    );
    return rows.map(EquipmentItem.fromMap).toList();
  }

  Future<int> addEquipment({
    required String stationNumber,
    required String category,
    required String description,
  }) async {
    final id = await _db.db.insert('station_equipment', {
      'station_number': stationNumber,
      'category': category,
      'description': description,
    });
    final sync = _sync;
    if (sync != null) {
      await sync.publishUpsert(
        entity: SyncEntity.stationEquipment,
        localPk: '$id',
      );
    }
    return id;
  }

  Future<void> deleteEquipment(int id) async {
    await _db.db.delete('station_equipment', where: 'id = ?', whereArgs: [id]);
    final sync = _sync;
    if (sync != null) {
      await sync.publishDelete(
        entity: SyncEntity.stationEquipment,
        localPk: '$id',
      );
    }
  }
}
