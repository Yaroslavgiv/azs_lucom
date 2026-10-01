import 'package:azs_app/core/models/station.dart';
import 'package:azs_app/core/models/station_access.dart';
import 'package:azs_domain/azs_domain.dart';
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

    test('specialist list hides stations of another person', () {
      final own = Station(
        number: '1',
        name: 'Своя',
        address: '',
        region: 'spb',
        specialistId: 'spec',
      );
      final other = Station(
        number: '2',
        name: 'Чужая',
        address: '',
        region: 'spb',
        crewId: 'crew',
        specialistId: 'other',
      );
      const specialist = AccessSubject(
        userId: 'spec',
        role: AppRole.specialist,
        crewId: 'crew',
      );
      final visible = stationsVisibleTo(specialist, [own, other]);
      expect(visible.map((station) => station.number), ['1']);
      expect(stationsVisibleTo(null, [own, other]), hasLength(2));
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
