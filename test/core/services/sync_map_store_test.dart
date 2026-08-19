import 'package:azs_app/core/services/sync_map_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('stores and resolves identifiers in both directions', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final store = SyncMapStore(database);

    await store.put(entity: 'requests', localId: '12', remoteId: 'remote-12');

    expect(await store.findRemoteId('requests', '12'), 'remote-12');
    expect(await store.findLocalId('requests', 'remote-12'), '12');
    expect(await store.findRemoteId('requests', 'missing'), isNull);
  });

  test('replaces an existing mapping for a local identifier', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final store = SyncMapStore(database);

    await store.put(entity: 'requests', localId: '12', remoteId: 'old');
    await store.put(entity: 'requests', localId: '12', remoteId: 'current');

    expect(await store.findRemoteId('requests', '12'), 'current');
    expect(await store.findLocalId('requests', 'old'), isNull);
  });

  test('removes one mapping or all mappings for an entity', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final store = SyncMapStore(database);
    await store.put(entity: 'requests', localId: '1', remoteId: 'remote-1');
    await store.put(entity: 'requests', localId: '2', remoteId: 'remote-2');
    await store.put(entity: 'stations', localId: '3', remoteId: 'remote-3');

    await store.remove('requests', '1');
    await store.clearEntity('requests');

    expect(await store.findRemoteId('requests', '1'), isNull);
    expect(await store.findRemoteId('requests', '2'), isNull);
    expect(await store.findRemoteId('stations', '3'), 'remote-3');
  });
}
