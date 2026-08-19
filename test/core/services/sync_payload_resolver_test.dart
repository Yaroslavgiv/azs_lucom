import 'package:azs_app/core/services/sync_change_publisher.dart';
import 'package:azs_app/core/services/sync_payload_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('builds a request payload from the local database', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final requestId = await database.db.insert('requests', {
      'station_number': '78001',
      'type': 'НЗ',
      'request_type': 'Срочная',
      'description': 'Описание',
      'date_created': '2026-08-19',
      'status': 'open',
    });
    final resolver = SyncPayloadResolver(database);

    final payload = await resolver.resolve(
      entity: SyncEntity.requests,
      localPk: '$requestId',
    );

    expect(payload, {
      'station_number': '78001',
      'type': 'НЗ',
      'request_type': 'Срочная',
      'description': 'Описание',
      'date_created': '2026-08-19',
      'status': 'open',
      'close_comment': null,
      'close_date': null,
    });
  });

  test('resolves composite maintenance keys safely', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    await database.db.insert('maintenance', {
      'station_number': '78001',
      'month': '2026-08',
      'status': 'done',
      'date_done': '2026-08-19 12:00',
      'to_type': 'Полное',
    });
    final resolver = SyncPayloadResolver(database);

    final payload = await resolver.resolve(
      entity: SyncEntity.maintenance,
      localPk: '78001_2026-08',
    );
    final invalidPayload = await resolver.resolve(
      entity: SyncEntity.maintenance,
      localPk: 'invalid',
    );

    expect(payload['station_number'], '78001');
    expect(payload['month'], '2026-08');
    expect(payload['status'], 'done');
    expect(invalidPayload, isEmpty);
  });
}
