import 'package:azs_app/core/models/request_item.dart';
import 'package:azs_app/core/models/station.dart';
import 'package:azs_app/core/repositories/maintenance_repository.dart';
import 'package:azs_app/core/services/manager_overview_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds KPI and attention list from stations and open requests', () async {
    final stats = await ManagerOverviewService(
      loadStations: () async => [
        Station(
          number: '78001',
          name: 'А',
          address: 'а',
          region: 'spb',
          lat: 1,
          lon: 1,
          geocodeStatus: 1,
        ),
        Station(
          number: '78002',
          name: 'Б',
          address: 'б',
          region: 'spb',
          lat: 1,
          lon: 1,
          geocodeStatus: 1,
        ),
      ],
      loadStatuses: () async => {
        '78001': MaintenanceStatus(status: 'done'),
      },
      loadOpenRequests: () async => [
        RequestItem(
          id: 1,
          stationNumber: '78002',
          type: 'НЗ',
          requestType: 'Срочная заявка',
          description: 'тест',
          dateCreated: '2026-09-01',
          status: 'open',
        ),
      ],
    ).load();

    expect(stats.stationCount, 2);
    expect(stats.maintenanceDone, 1);
    expect(stats.maintenancePending, 1);
    expect(stats.openRequests, 1);
    expect(stats.attentionItems, isNotEmpty);
  });
}
