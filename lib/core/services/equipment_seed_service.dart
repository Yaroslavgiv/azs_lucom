import 'dart:convert';

import 'package:flutter/services.dart';

import '../database/app_database.dart';

/// Импорт оборудования (Пожарка / КТСБ) из assets/station_equipment.json.
class EquipmentSeedService {
  EquipmentSeedService(this._db);

  /// Увеличьте версию после обновления station_equipment.json.
  static const _dataVersion = '2';

  final AppDatabase _db;

  Future<void> seedIfNeeded() async {
    final currentVersion = await _db.getMeta('equipment_data_version');
    if (currentVersion == _dataVersion) return;

    final jsonStr = await rootBundle.loadString('assets/station_equipment.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final stationNumbers =
        (data['station_numbers'] as List<dynamic>).cast<String>();
    final equipment = data['equipment'] as List<dynamic>? ?? [];

    final categories = <String>{
      for (final item in equipment)
        (item as Map<String, dynamic>)['category'] as String,
    };

    final placeholders = List.filled(stationNumbers.length, '?').join(',');

    await _db.db.transaction((txn) async {
      for (final category in categories) {
        await txn.rawDelete(
          'DELETE FROM station_equipment WHERE station_number IN ($placeholders) AND category = ?',
          [...stationNumbers, category],
        );
      }

      for (final item in equipment) {
        final m = item as Map<String, dynamic>;
        await txn.insert('station_equipment', {
          'station_number': m['station_number'],
          'category': m['category'],
          'description': m['description'] ?? '',
        });
      }
    });

    await _db.setMeta('equipment_data_version', _dataVersion);
  }
}
