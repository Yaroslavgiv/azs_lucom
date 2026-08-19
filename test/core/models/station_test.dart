import 'package:azs_app/core/models/station.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Station', () {
    test('maps a complete database row', () {
      final station = Station.fromMap({
        'number': '78001',
        'name': 'Лукойл',
        'address': 'Санкт-Петербург',
        'region': 'spb',
        'lat': 59.93,
        'lon': 30.31,
        'geocode_status': 1,
      });

      expect(station.number, '78001');
      expect(station.hasCoordinates, isTrue);
      expect(station.displayTitle, 'Лукойл');
      expect(station.toMap()['region'], 'spb');
    });

    test('uses address as a fallback display title', () {
      final station = Station(
        number: '53001',
        name: '',
        address: 'Великий Новгород',
        region: 'novgorod',
      );

      expect(station.displayTitle, 'Великий Новгород');
      expect(station.hasCoordinates, isFalse);
    });

    test('uses station number when name and address are empty', () {
      final station = Station(
        number: '53002',
        name: '',
        address: '',
        region: 'novgorod',
      );

      expect(station.displayTitle, 'АЗС 53002');
    });
  });
}
