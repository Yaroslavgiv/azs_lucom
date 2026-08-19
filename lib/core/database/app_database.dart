import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this._database);

  static Future<AppDatabase>? _instance;
  final Database _database;

  static Future<AppDatabase> get instance => _instance ??= _openDefault();

  static Future<AppDatabase> _openDefault() async {
    return AppDatabase._(await _init());
  }

  static Future<AppDatabase> openForTesting(DatabaseFactory factory) async {
    final database = await factory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (database, _) => _createSchema(database),
      ),
    );
    return AppDatabase._(database);
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'azs_app.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS equipment_order_exports (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              region TEXT NOT NULL,
              export_date TEXT NOT NULL,
              request_id INTEGER NOT NULL,
              FOREIGN KEY (request_id) REFERENCES requests(id)
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS defect_acts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              station_number TEXT NOT NULL,
              created_at TEXT NOT NULL,
              equipment_category TEXT NOT NULL DEFAULT '',
              equipment_name TEXT NOT NULL DEFAULT '',
              assessment TEXT NOT NULL DEFAULT '',
              declared_fault TEXT NOT NULL DEFAULT '',
              faulty TEXT NOT NULL DEFAULT '',
              conclusion TEXT NOT NULL DEFAULT '',
              rendered_text TEXT NOT NULL DEFAULT '',
              FOREIGN KEY (station_number) REFERENCES stations(number)
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_defect_acts_station_created ON defect_acts(station_number, created_at)',
          );
        }
        if (oldVersion < 4) {
          await _createSyncTables(db);
        }
        if (oldVersion < 5) {
          await _deduplicateSyncQueue(db);
          await _createSyncQueueUniqueIndex(db);
        }
      },
    );
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
          CREATE TABLE stations (
            number TEXT PRIMARY KEY,
            name TEXT NOT NULL DEFAULT '',
            address TEXT NOT NULL DEFAULT '',
            lat REAL,
            lon REAL,
            region TEXT NOT NULL,
            geocode_status INTEGER NOT NULL DEFAULT 0
          )
        ''');
    await db.execute('''
          CREATE TABLE requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            station_number TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'НЗ',
            request_type TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            date_created TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'open',
            close_comment TEXT,
            close_date TEXT,
            FOREIGN KEY (station_number) REFERENCES stations(number)
          )
        ''');
    await db.execute('''
          CREATE TABLE maintenance (
            station_number TEXT NOT NULL,
            month TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            date_done TEXT,
            to_type TEXT,
            PRIMARY KEY (station_number, month)
          )
        ''');
    await db.execute('''
          CREATE TABLE station_info (
            station_number TEXT PRIMARY KEY,
            manager_contact TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (station_number) REFERENCES stations(number)
          )
        ''');
    await db.execute('''
          CREATE TABLE station_equipment (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            station_number TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (station_number) REFERENCES stations(number)
          )
        ''');
    await db.execute('''
          CREATE TABLE app_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
    await db.execute('''
          CREATE TABLE equipment_order_exports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            region TEXT NOT NULL,
            export_date TEXT NOT NULL,
            request_id INTEGER NOT NULL,
            FOREIGN KEY (request_id) REFERENCES requests(id)
          )
        ''');
    await db.execute('''
          CREATE TABLE defect_acts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            station_number TEXT NOT NULL,
            created_at TEXT NOT NULL,
            equipment_category TEXT NOT NULL DEFAULT '',
            equipment_name TEXT NOT NULL DEFAULT '',
            assessment TEXT NOT NULL DEFAULT '',
            declared_fault TEXT NOT NULL DEFAULT '',
            faulty TEXT NOT NULL DEFAULT '',
            conclusion TEXT NOT NULL DEFAULT '',
            rendered_text TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (station_number) REFERENCES stations(number)
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_defect_acts_station_created ON defect_acts(station_number, created_at)',
    );
    await _createSyncTables(db);
  }

  static Future<void> _createSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        local_pk TEXT NOT NULL,
        op TEXT NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_map (
        entity TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id TEXT NOT NULL,
        PRIMARY KEY (entity, local_id)
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_map_remote ON sync_map(entity, remote_id)',
    );
    await _createSyncQueueUniqueIndex(db);
  }

  static Future<void> _deduplicateSyncQueue(Database database) async {
    await database.execute('''
      DELETE FROM sync_queue
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM sync_queue
        GROUP BY entity, local_pk
      )
    ''');
  }

  static Future<void> _createSyncQueueUniqueIndex(Database database) async {
    await database.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_queue_entity_local '
      'ON sync_queue(entity, local_pk)',
    );
  }

  Database get db => _database;

  Future<void> close() => _database.close();

  Future<bool> isSeeded() async {
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['seeded'],
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  Future<void> markSeeded() async {
    await setMeta('seeded', '1');
  }

  Future<String?> getMeta(String key) async {
    final rows = await db.query('app_meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    await db.insert('app_meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
