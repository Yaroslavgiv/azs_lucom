import 'package:azs_domain/azs_domain.dart';

import '../database/app_database.dart';

class FilteredReportBuilder {
  const FilteredReportBuilder(this._db);

  final AppDatabase _db;

  Future<List<Map<String, Object?>>> build({
    required PanelFilter filter,
    required DateTime generatedAt,
  }) async {
    final syncedAt = await _db.getMeta('last_pull_at');
    final requests = await _db.db.rawQuery('''
      SELECT r.id, r.station_number, r.workflow_status, r.assignee_id,
             r.critical, r.due_at, r.date_created, r.status,
             s.region, s.management_id, s.department_id, s.crew_id
      FROM requests r
      JOIN stations s ON s.number = r.station_number
    ''');
    final maintenance = await _db.db.rawQuery('''
      SELECT m.station_number, m.month, m.workflow_status, m.assignee_id,
             m.due_at, m.status, s.region, s.management_id, s.department_id, s.crew_id
      FROM maintenance m
      JOIN stations s ON s.number = m.station_number
    ''');
    final items = <PanelWorkItem>[
      for (final row in requests)
        PanelWorkItem(
          id: '${row['id']}',
          kind: 'request',
          stationNumber: row['station_number'] as String,
          status: (row['workflow_status'] as String?) ?? 'created',
          overdue: _overdue(
            row['due_at'] as String?,
            row['workflow_status'] as String?,
          ),
          critical: (row['critical'] as int? ?? 0) == 1,
          region: row['region'] as String?,
          managementId: row['management_id'] as String?,
          departmentId: row['department_id'] as String?,
          crewId: row['crew_id'] as String?,
          assigneeId: row['assignee_id'] as String?,
          createdAt: DateTime.tryParse((row['date_created'] as String?) ?? ''),
        ),
      for (final row in maintenance)
        PanelWorkItem(
          id: '${row['station_number']}_${row['month']}',
          kind: 'maintenance',
          stationNumber: row['station_number'] as String,
          status: (row['workflow_status'] as String?) ?? 'planned',
          overdue: _overdue(
            row['due_at'] as String?,
            row['workflow_status'] as String?,
          ),
          critical: false,
          region: row['region'] as String?,
          managementId: row['management_id'] as String?,
          departmentId: row['department_id'] as String?,
          crewId: row['crew_id'] as String?,
          assigneeId: row['assignee_id'] as String?,
        ),
    ];
    final generated = generatedAt.toIso8601String();
    return [
      for (final item in items.where(filter.matches))
        {
          'kind': item.kind,
          'id': item.id,
          'station_number': item.stationNumber,
          'region': item.region ?? '',
          'status': item.status,
          'assignee_id': item.assigneeId ?? '',
          'overdue': item.overdue ? 'да' : 'нет',
          'generated_at': generated,
          'synced_at': syncedAt ?? '',
        },
    ];
  }

  bool _overdue(String? dueAt, String? status) {
    final due = DateTime.tryParse(dueAt ?? '');
    return isOverdue(
      dueAt: due,
      workflowStatus: status ?? '',
      now: DateTime.now(),
    );
  }
}
