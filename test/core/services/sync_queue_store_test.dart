import 'package:azs_lucom/core/services/sync_queue_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('returns queued operations in insertion order', () async {
    final database = await createTestDatabase();
    addTearDown(database.close);
    final queue = SyncQueueStore(database);

    await queue.put(
      entity: 'stations',
      localPk: '1',
      operation: 'upsert',
      payload: {'name': 'First'},
    );
    await queue.put(entity: 'requests', localPk: '2', operation: 'delete');

    final items = await queue.nextBatch();

    expect(items.map((item) => item.localPk), ['1', '2']);
    expect(items.first.operation, 'upsert');
    expect(items.first.payload, {'name': 'First'});
    expect(items.last.payload, isEmpty);
  });

  test('coalesces repeated changes for the same local record', () async {
    final database = await createTestDatabase();
    addTearDown(database.close);
    final queue = SyncQueueStore(database);

    await queue.put(
      entity: 'stations',
      localPk: '1',
      operation: 'upsert',
      payload: {'name': 'Old'},
    );
    await queue.put(
      entity: 'stations',
      localPk: '1',
      operation: 'upsert',
      payload: {'name': 'Current'},
    );

    final items = await queue.nextBatch();

    expect(items, hasLength(1));
    expect(items.single.payload, {'name': 'Current'});
  });

  test('removes only the acknowledged queue item', () async {
    final database = await createTestDatabase();
    addTearDown(database.close);
    final queue = SyncQueueStore(database);

    await queue.put(entity: 'stations', localPk: '1', operation: 'delete');
    await queue.put(entity: 'stations', localPk: '2', operation: 'delete');
    final first = (await queue.nextBatch()).first;

    await queue.remove(first.id);

    final remaining = await queue.nextBatch();
    expect(remaining, hasLength(1));
    expect(remaining.single.localPk, '2');
  });
}
