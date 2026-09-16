import 'package:azs_app/core/domain/maintenance_lifecycle.dart';
import 'package:azs_app/core/models/station.dart';
import 'package:azs_app/core/repositories/maintenance_repository.dart';
import 'package:azs_app/core/repositories/station_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('submitForReview does not mark maintenance as accepted', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    await StationRepository(
      database,
    ).upsert(Station(number: '78001', name: 'АЗС', address: '', region: 'spb'));
    final repository = MaintenanceRepository(database);

    await repository.submitForReview('78001', comment: 'Проверено');
    final status = await repository.getStatus('78001');

    expect(status.isDone, isFalse);
    expect(status.status, MaintenanceLifecycle.inReview);

    await repository.applyReview(
      stationNumber: '78001',
      status: MaintenanceLifecycle.accepted,
      reviewerId: 'manager',
    );
    expect((await repository.getStatus('78001')).isDone, isTrue);
  });
}
