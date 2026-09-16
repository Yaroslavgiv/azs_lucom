import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this._database);

  static const schemaVersion = 6;

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
        version: schemaVersion,
        onCreate: (database, _) => _createSchema(database),
      ),
    );
    return AppDatabase._(database);
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'azs_app.db');
    return openDatabase(
      path,
      version: schemaVersion,
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
        if (oldVersion < 6) {
          await _upgradeToV6(db);
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
            geocode_status INTEGER NOT NULL DEFAULT 0,
            updated_by TEXT,
            updated_at TEXT
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
            status TEXT NOT NULL DEFAULT 'new',
            close_comment TEXT,
            close_date TEXT,
            assignee_id TEXT,
            assignee_name TEXT,
            due_date TEXT,
            updated_by TEXT,
            updated_at TEXT,
            version INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY (station_number) REFERENCES stations(number)
          )
        ''');
    await db.execute('''
          CREATE TABLE maintenance (
            station_number TEXT NOT NULL,
            month TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'planned',
            date_done TEXT,
            to_type TEXT,
            assignee_id TEXT,
            assignee_name TEXT,
            due_date TEXT,
            comment TEXT,
            report_json TEXT,
            photo_paths TEXT,
            updated_by TEXT,
            updated_at TEXT,
            submitted_at TEXT,
            reviewed_by TEXT,
            review_comment TEXT,
            version INTEGER NOT NULL DEFAULT 1,
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
            quantity INTEGER NOT NULL DEFAULT 1,
            serial_number TEXT NOT NULL DEFAULT '',
            condition TEXT NOT NULL DEFAULT 'Исправно',
            updated_by TEXT,
            updated_at TEXT,
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
    await _createWorkflowTables(db);
    await _createSyncTables(db);
  }

  static Future<void> _createWorkflowTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users_cache (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL DEFAULT '',
        display_name TEXT NOT NULL DEFAULT '',
        role TEXT NOT NULL DEFAULT 'specialist',
        regions TEXT NOT NULL DEFAULT 'spb,novgorod',
        disabled INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        actor_id TEXT NOT NULL DEFAULT '',
        actor_name TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        summary TEXT NOT NULL DEFAULT '',
        payload_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attachment_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        local_pk TEXT NOT NULL,
        local_path TEXT NOT NULL,
        remote_url TEXT,
        created_at TEXT NOT NULL,
        uploaded INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _upgradeToV6(Database db) async {
    await _addColumn(db, 'stations', 'updated_by', 'TEXT');
    await _addColumn(db, 'stations', 'updated_at', 'TEXT');
    await _addColumn(db, 'requests', 'assignee_id', 'TEXT');
    await _addColumn(db, 'requests', 'assignee_name', 'TEXT');
    await _addColumn(db, 'requests', 'due_date', 'TEXT');
    await _addColumn(db, 'requests', 'updated_by', 'TEXT');
    await _addColumn(db, 'requests', 'updated_at', 'TEXT');
    await _addColumn(db, 'requests', 'version', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumn(db, 'maintenance', 'assignee_id', 'TEXT');
    await _addColumn(db, 'maintenance', 'assignee_name', 'TEXT');
    await _addColumn(db, 'maintenance', 'due_date', 'TEXT');
    await _addColumn(db, 'maintenance', 'comment', 'TEXT');
    await _addColumn(db, 'maintenance', 'report_json', 'TEXT');
    await _addColumn(db, 'maintenance', 'photo_paths', 'TEXT');
    await _addColumn(db, 'maintenance', 'updated_by', 'TEXT');
    await _addColumn(db, 'maintenance', 'updated_at', 'TEXT');
    await _addColumn(db, 'maintenance', 'submitted_at', 'TEXT');
    await _addColumn(db, 'maintenance', 'reviewed_by', 'TEXT');
    await _addColumn(db, 'maintenance', 'review_comment', 'TEXT');
    await _addColumn(
      db,
      'maintenance',
      'version',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumn(
      db,
      'station_equipment',
      'quantity',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumn(
      db,
      'station_equipment',
      'serial_number',
      'TEXT NOT NULL DEFAULT \'\'',
    );
    await _addColumn(
      db,
      'station_equipment',
      'condition',
      'TEXT NOT NULL DEFAULT \'Исправно\'',
    );
    await _addColumn(db, 'station_equipment', 'updated_by', 'TEXT');
    await _addColumn(db, 'station_equipment', 'updated_at', 'TEXT');
    await _createWorkflowTables(db);
    await db.execute(
      "UPDATE requests SET status = 'new' WHERE status = 'open'",
    );
    await db.execute(
      "UPDATE requests SET status = 'done' WHERE status = 'closed'",
    );
    await db.execute(
      "UPDATE maintenance SET status = 'planned' WHERE status = 'pending'",
    );
    await db.execute(
      "UPDATE maintenance SET status = 'accepted' WHERE status = 'done'",
    );
  }

  static Future<void> _addColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
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
