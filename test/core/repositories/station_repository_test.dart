import 'package:azs_app/core/models/station.dart';
import 'package:azs_app/core/repositories/station_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('filters and orders stations by region', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final repository = StationRepository(database);

    await repository.upsert(
      Station(number: '78010', name: 'Вторая', address: '', region: 'spb'),
    );
    await repository.upsert(
      Station(number: '78002', name: 'Первая', address: '', region: 'spb'),
    );
    await repository.upsert(
      Station(
        number: '53001',
        name: 'Новгород',
        address: '',
        region: 'novgorod',
      ),
    );

    final stations = await repository.getByRegion('spb');

    expect(stations.map((station) => station.number), ['78002', '78010']);
  });

  test('updates coordinates and geocoding status', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final repository = StationRepository(database);
    await repository.upsert(
      Station(number: '78001', name: '', address: '', region: 'spb'),
    );

    await repository.updateGeocode(
      number: '78001',
      name: 'АЗС 78001',
      address: 'Санкт-Петербург',
      lat: 59.93,
      lon: 30.31,
    );

    final station = await repository.getByNumber('78001');
    expect(station?.hasCoordinates, isTrue);
    expect(station?.geocodeStatus, 1);
    expect(await repository.getNeedingGeocode(), isEmpty);
  });
}
