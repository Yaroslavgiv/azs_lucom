import 'dart:developer' as developer;

abstract interface class SyncLogger {
  void error(
    String operation,
    Object error,
    StackTrace stackTrace,
  );
}

class DeveloperSyncLogger implements SyncLogger {
  const DeveloperSyncLogger();

  @override
  void error(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      operation,
      name: 'azs.sync',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
