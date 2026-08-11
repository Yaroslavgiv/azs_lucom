import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// Импорт заявок и ТО из assets/operational_data.json (экспорт из azs.db).
class OperationalDataSeedService {
  OperationalDataSeedService(this._db);

  /// Увеличьте версию после обновления operational_data.json.
  static const _dataVersion = '1';

  final AppDatabase _db;

  Future<void> seedIfNeeded() async {
    final currentVersion = await _db.getMeta('operational_data_version');
    if (currentVersion == _dataVersion) return;

    final jsonStr = await rootBundle.loadString('assets/operational_data.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final stationNumbers =
        (data['station_numbers'] as List<dynamic>).cast<String>();
    final requests = data['requests'] as List<dynamic>? ?? [];
    final maintenance = data['maintenance'] as List<dynamic>? ?? [];

    final placeholders = List.filled(stationNumbers.length, '?').join(',');

    await _db.db.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM requests WHERE station_number IN ($placeholders)',
        stationNumbers,
      );
      await txn.rawDelete(
        'DELETE FROM maintenance WHERE station_number IN ($placeholders)',
        stationNumbers,
      );

      for (final item in requests) {
        final m = item as Map<String, dynamic>;
        await txn.insert('requests', {
          'station_number': m['station_number'],
          'type': m['type'] ?? 'НЗ',
          'request_type': m['request_type'] ?? 'Не срочная заявка',
          'description': m['description'] ?? '',
          'date_created': m['date_created'],
          'status': m['status'] ?? 'open',
          'close_comment': m['close_comment'],
          'close_date': m['close_date'],
        });
      }

      for (final item in maintenance) {
        final m = item as Map<String, dynamic>;
        await txn.insert(
          'maintenance',
          {
            'station_number': m['station_number'],
            'month': m['month'],
            'status': m['status'] ?? 'pending',
            'date_done': m['date_done'],
            'to_type': m['to_type'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    await _db.setMeta('operational_data_version', _dataVersion);
  }
}
