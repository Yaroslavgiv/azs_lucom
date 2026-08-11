import 'dart:convert';

import 'package:flutter/services.dart';

import '../database/app_database.dart';
import '../models/station.dart';
import '../repositories/station_repository.dart';

class StationSeedService {
  StationSeedService(this._db, this._stations);

  /// Увеличьте версию, чтобы один раз обновить справочник из assets у существующих установок.
  static const _seedVersion = '6';

  final AppDatabase _db;
  final StationRepository _stations;

  Future<void> seedIfNeeded() async {
    final currentVersion = await _db.getMeta('stations_seed_version');
    if (await _db.isSeeded() && currentVersion == _seedVersion) {
      return;
    }

    final jsonStr = await rootBundle.loadString('assets/stations_yandex.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;

    for (final region in ['spb', 'novgorod']) {
      final list = data[region] as List<dynamic>? ?? [];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final number = m['number'] as String;
        final jsonLat = m['lat'];
        final jsonLon = m['lon'];

        final lat = jsonLat == null ? null : (jsonLat as num).toDouble();
        final lon = jsonLon == null ? null : (jsonLon as num).toDouble();
        final address = (m['address'] as String?) ?? '';
        final name = (m['name'] as String?) ?? 'АЗС $number';

        final station = Station(
          number: number,
          name: name,
          address: address,
          region: region,
          lat: lat,
          lon: lon,
          geocodeStatus: lat != null && lon != null ? 1 : 0,
        );
        await _stations.upsert(station);

        final infoRows = await _db.db.query(
          'station_info',
          where: 'station_number = ?',
          whereArgs: [number],
          limit: 1,
        );
        if (infoRows.isEmpty) {
          await _db.db.insert(
            'station_info',
            {'station_number': number, 'manager_contact': ''},
          );
        }
      }
    }

    await _db.markSeeded();
    await _db.setMeta('stations_seed_version', _seedVersion);
  }
}
