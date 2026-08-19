import 'package:azs_app/core/models/station.dart';
import 'package:azs_app/core/repositories/request_repository.dart';
import 'package:azs_app/core/repositories/station_repository.dart';
import 'package:azs_app/core/services/sync_change_publisher.dart';
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

  test('publishes local changes through the sync abstraction', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final publisher = _RecordingSyncPublisher();
    final repository = RequestRepository(database, sync: publisher);

    final id = await repository.add(
      stationNumber: '78001',
      requestType: 'Срочная заявка',
      description: 'Описание',
    );
    await repository.updateDescription(id, 'Новое описание');
    await repository.close(id);

    expect(publisher.upserts, [
      (entity: SyncEntity.requests, localPk: '$id'),
      (entity: SyncEntity.requests, localPk: '$id'),
      (entity: SyncEntity.requests, localPk: '$id'),
    ]);
  });
}

class _RecordingSyncPublisher implements SyncChangePublisher {
  final upserts = <({String entity, String localPk})>[];

  @override
  Future<void> publishUpsert({
    required String entity,
    required String localPk,
  }) async {
    upserts.add((entity: entity, localPk: localPk));
  }

  @override
  Future<void> publishDelete({
    required String entity,
    required String localPk,
  }) async {}

  @override
  Future<void> publishUpsertPayload({
    required String entity,
    required String localPk,
    required Map<String, Object?> payload,
  }) async {
    upserts.add((entity: entity, localPk: localPk));
  }
}
