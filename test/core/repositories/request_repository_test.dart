import 'package:azs_app/core/models/station.dart';
import 'package:azs_app/core/repositories/request_repository.dart';
import 'package:azs_app/core/repositories/station_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('creates, updates and closes a station request', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    await StationRepository(
      database,
    ).upsert(Station(number: '78001', name: 'АЗС', address: '', region: 'spb'));
    final repository = RequestRepository(database);

    final id = await repository.add(
      stationNumber: '78001',
      requestType: 'Срочная заявка',
      description: 'Первичное описание',
    );
    await repository.updateDescription(id, 'Уточнённое описание');

    final openRequests = await repository.getOpenByStation('78001');
    expect(openRequests, hasLength(1));
    expect(openRequests.single.description, 'Уточнённое описание');

    await repository.close(id, comment: 'Выполнено');

    expect(await repository.getOpenByStation('78001'), isEmpty);
    final rows = await database.db.query(
      'requests',
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(rows.single['status'], 'closed');
    expect(rows.single['close_comment'], 'Выполнено');
  });
}
