import 'bootstrap_stub.dart'
    if (dart.library.io) 'bootstrap_io.dart'
    if (dart.library.html) 'bootstrap_web.dart'
    as platform_bootstrap;

/// Desktop/web need an explicit SQLite factory; mobile uses the default plugin.
Future<void> configureLocalDatabase() =>
    platform_bootstrap.configureLocalDatabase();
