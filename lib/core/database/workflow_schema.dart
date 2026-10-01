import 'package:sqflite/sqflite.dart';

Future<void> createWorkflowTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS managements (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      head_user_id TEXT,
      active INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS departments (
      id TEXT PRIMARY KEY,
      management_id TEXT NOT NULL,
      name TEXT NOT NULL,
      head_user_id TEXT,
      active INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS crews (
      id TEXT PRIMARY KEY,
      department_id TEXT NOT NULL,
      name TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS user_profiles (
      user_id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL DEFAULT '',
      role TEXT NOT NULL,
      management_id TEXT,
      department_id TEXT,
      crew_id TEXT,
      manager_scope TEXT,
      active INTEGER NOT NULL DEFAULT 1,
      contact TEXT NOT NULL DEFAULT '',
      fcm_token TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS station_assignment_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      station_number TEXT NOT NULL,
      previous_crew_id TEXT,
      new_crew_id TEXT,
      previous_department_id TEXT,
      new_department_id TEXT,
      author_id TEXT,
      changed_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS checklist_templates (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      regulation_id TEXT,
      version INTEGER NOT NULL DEFAULT 1,
      items_json TEXT NOT NULL DEFAULT '[]',
      active INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS checklist_results (
      id TEXT PRIMARY KEY,
      maintenance_key TEXT NOT NULL,
      item_id TEXT NOT NULL,
      result TEXT,
      comment TEXT,
      equipment_id TEXT,
      author_id TEXT,
      updated_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS equipment_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      equipment_id INTEGER NOT NULL,
      field_name TEXT NOT NULL,
      previous_value TEXT,
      new_value TEXT,
      author_id TEXT,
      changed_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS comments (
      id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      body TEXT NOT NULL,
      purpose TEXT NOT NULL DEFAULT '',
      author_id TEXT,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS attachments (
      id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      local_path TEXT,
      storage_path TEXT,
      file_name TEXT NOT NULL,
      mime_type TEXT NOT NULL DEFAULT '',
      size_bytes INTEGER NOT NULL DEFAULT 0,
      author_id TEXT,
      created_at TEXT NOT NULL,
      upload_state TEXT NOT NULL DEFAULT 'pending'
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS audit_events (
      id TEXT PRIMARY KEY,
      actor_id TEXT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      action TEXT NOT NULL,
      previous_value TEXT,
      new_value TEXT,
      created_at TEXT NOT NULL,
      management_id TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY,
      recipient_id TEXT NOT NULL,
      event_key TEXT NOT NULL UNIQUE,
      type TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      read_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS contract_rules (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      duration_hours INTEGER,
      requires_review INTEGER NOT NULL DEFAULT 0,
      effective_from TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      active INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS reference_values (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      code TEXT NOT NULL,
      name TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0,
      version INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    INSERT OR IGNORE INTO checklist_templates (
      id, name, regulation_id, version, items_json, active
    ) VALUES (
      'default-to',
      'Регламент ТО',
      'default',
      1,
      '[{"id":"pumps","title":"ТРК","required":true},{"id":"tanks","title":"Резервуары","required":true},{"id":"electric","title":"Электрика","required":false},{"id":"fire","title":"Пожарка","required":true}]',
      1
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_assignment_history_station ON station_assignment_history(station_number, changed_at)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id, created_at)',
  );
}

Future<void> migrateToWorkflowSchema(Database db) async {
  await _addColumn(db, 'stations', 'management_id', 'TEXT');
  await _addColumn(db, 'stations', 'department_id', 'TEXT');
  await _addColumn(db, 'stations', 'crew_id', 'TEXT');
  await _addColumn(db, 'stations', 'active', 'INTEGER NOT NULL DEFAULT 1');
  await _addColumn(db, 'stations', 'created_by', 'TEXT');
  await _addColumn(db, 'stations', 'created_at', 'TEXT');
  await _addColumn(db, 'stations', 'input_method', 'TEXT');

  await _addColumn(db, 'requests', 'uuid', 'TEXT');
  await _addColumn(db, 'requests', 'category', "TEXT NOT NULL DEFAULT ''");
  await _addColumn(db, 'requests', 'author_id', 'TEXT');
  await _addColumn(db, 'requests', 'assignee_id', 'TEXT');
  await _addColumn(db, 'requests', 'due_at', 'TEXT');
  await _addColumn(db, 'requests', 'result_text', 'TEXT');
  await _addColumn(db, 'requests', 'critical', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumn(db, 'requests', 'revision', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumn(
    db,
    'requests',
    'workflow_status',
    "TEXT NOT NULL DEFAULT 'created'",
  );
  await _addColumn(db, 'requests', 'last_command_key', 'TEXT');
  await _addColumn(
    db,
    'requests',
    'source',
    "TEXT NOT NULL DEFAULT 'internal'",
  );
  await _addColumn(db, 'requests', 'source_external_id', 'TEXT');
  await _addColumn(db, 'requests', 'management_id', 'TEXT');
  await _addColumn(db, 'requests', 'department_id', 'TEXT');
  await _addColumn(db, 'requests', 'crew_id', 'TEXT');

  await _addColumn(db, 'maintenance', 'uuid', 'TEXT');
  await _addColumn(db, 'maintenance', 'assignee_id', 'TEXT');
  await _addColumn(db, 'maintenance', 'due_at', 'TEXT');
  await _addColumn(db, 'maintenance', 'regulation_id', 'TEXT');
  await _addColumn(db, 'maintenance', 'accepted_at', 'TEXT');
  await _addColumn(
    db,
    'maintenance',
    'workflow_status',
    "TEXT NOT NULL DEFAULT 'planned'",
  );
  await _addColumn(db, 'maintenance', 'revision', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumn(db, 'maintenance', 'result_text', 'TEXT');
  await _addColumn(db, 'maintenance', 'last_command_key', 'TEXT');
  await _addColumn(db, 'maintenance', 'author_id', 'TEXT');
  await _addColumn(db, 'maintenance', 'management_id', 'TEXT');
  await _addColumn(db, 'maintenance', 'department_id', 'TEXT');
  await _addColumn(db, 'maintenance', 'crew_id', 'TEXT');

  await _addColumn(
    db,
    'station_equipment',
    'model',
    "TEXT NOT NULL DEFAULT ''",
  );
  await _addColumn(
    db,
    'station_equipment',
    'quantity',
    'INTEGER NOT NULL DEFAULT 1',
  );
  await _addColumn(db, 'station_equipment', 'serial_number', 'TEXT');
  await _addColumn(
    db,
    'station_equipment',
    'condition',
    "TEXT NOT NULL DEFAULT ''",
  );
  await _addColumn(db, 'station_equipment', 'updated_by', 'TEXT');
  await _addColumn(db, 'station_equipment', 'updated_at', 'TEXT');

  await _addColumn(db, 'sync_queue', 'attempts', 'INTEGER NOT NULL DEFAULT 0');
  await _addColumn(db, 'sync_queue', 'last_error', 'TEXT');
  await _addColumn(
    db,
    'sync_queue',
    'state',
    "TEXT NOT NULL DEFAULT 'pending'",
  );
  await _addColumn(db, 'sync_queue', 'idempotency_key', 'TEXT');
  await _addColumn(db, 'sync_queue', 'depends_on', 'TEXT');
  await _addColumn(db, 'sync_queue', 'next_attempt_at', 'TEXT');

  await db.execute(
    "UPDATE requests SET workflow_status = 'accepted' WHERE status = 'closed' AND workflow_status = 'created'",
  );
  await db.execute(
    "UPDATE maintenance SET workflow_status = 'accepted' WHERE status = 'done' AND workflow_status = 'planned'",
  );
  await createWorkflowTables(db);
}

Future<void> migrateToServiceCycleSchema(Database db) async {
  await _addColumn(db, 'stations', 'specialist_id', 'TEXT');
  await _addColumn(
    db,
    'requests',
    'requires_review',
    'INTEGER NOT NULL DEFAULT 0',
  );
  await _addColumn(db, 'user_profiles', 'manager_scope', 'TEXT');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS contract_rules (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      duration_hours INTEGER,
      requires_review INTEGER NOT NULL DEFAULT 0,
      effective_from TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      active INTEGER NOT NULL DEFAULT 1
    )
  ''');
}

Future<void> _addColumn(
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
