import 'package:azs_app/core/services/sync_logger.dart';
import 'package:azs_app/core/services/sync_push_transport.dart';
import 'package:azs_app/core/services/sync_queue_flusher.dart';
import 'package:azs_app/core/services/sync_queue_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('removes queue items only after a successful push', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final queue = SyncQueueStore(database);
    final transport = _RecordingPushTransport();
    final flusher = SyncQueueFlusher(
      queueStore: queue,
      pushTransport: transport,
      logger: _RecordingLogger(),
    );
    await queue.put(entity: 'requests', localPk: '1', operation: 'upsert');

    await flusher.flush();

    expect(transport.pushedLocalIds, ['1']);
    expect(await queue.nextBatch(), isEmpty);
  });

  test('retains the failed item and stops the current flush', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final queue = SyncQueueStore(database);
    final transport = _RecordingPushTransport(failingLocalId: '1');
    final logger = _RecordingLogger();
    final flusher = SyncQueueFlusher(
      queueStore: queue,
      pushTransport: transport,
      logger: logger,
    );
    await queue.put(entity: 'requests', localPk: '1', operation: 'upsert');
    await queue.put(entity: 'requests', localPk: '2', operation: 'upsert');

    await flusher.flush();

    expect(transport.pushedLocalIds, ['1']);
    expect((await queue.nextBatch()).map((item) => item.localPk), ['1', '2']);
    expect(logger.operations, ['Failed to flush requests/1']);
  });
}

class _RecordingPushTransport implements SyncPushTransport {
  _RecordingPushTransport({this.failingLocalId});

  final String? failingLocalId;
  final pushedLocalIds = <String>[];

  @override
  Future<void> push(SyncQueueItem item) async {
    pushedLocalIds.add(item.localPk);
    if (item.localPk == failingLocalId) throw StateError('push failed');
  }
}

class _RecordingLogger implements SyncLogger {
  final operations = <String>[];

  @override
  void error(String operation, Object error, StackTrace stackTrace) {
    operations.add(operation);
  }
}
