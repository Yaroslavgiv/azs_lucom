import 'sync_logger.dart';
import 'sync_push_transport.dart';
import 'sync_queue_store.dart';

class SyncQueueFlusher {
  SyncQueueFlusher({
    required SyncQueueStore queueStore,
    required SyncPushTransport pushTransport,
    required SyncLogger logger,
  }) : _queueStore = queueStore,
       _pushTransport = pushTransport,
       _logger = logger;

  final SyncQueueStore _queueStore;
  final SyncPushTransport _pushTransport;
  final SyncLogger _logger;

  bool _isFlushing = false;

  Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      await _flushBatches();
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _flushBatches() async {
    while (true) {
      final items = await _queueStore.nextBatch();
      if (items.isEmpty) return;
      for (final item in items) {
        try {
          await _pushTransport.push(item);
          await _queueStore.remove(item.id);
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to flush ${item.entity}/${item.localPk}',
            error,
            stackTrace,
          );
          return;
        }
      }
    }
  }
}
