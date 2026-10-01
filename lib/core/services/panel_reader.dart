import 'package:azs_domain/azs_domain.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/app_database.dart';
import 'filtered_report.dart';

class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.active,
  });

  final String id;
  final String kind;
  final String name;
  final bool active;
}

class AuditRow {
  const AuditRow({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.actorId,
    this.managementId,
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String createdAt;
  final String? actorId;
  final String? managementId;
}

class PanelSnapshot {
  const PanelSnapshot({
    required this.metrics,
    required this.work,
    required this.stations,
    required this.audit,
    required this.directories,
    required this.users,
  });

  final PanelMetrics metrics;
  final List<PanelWorkItem> work;
  final List<OrgStation> stations;
  final List<AuditRow> audit;
  final List<DirectoryEntry> directories;
  final List<AccessSubject> users;
}

class SqlitePanelReader {
  const SqlitePanelReader(this._db);

  final AppDatabase _db;

  Future<PanelSnapshot> load(PanelFilter filter, AccessSubject? actor) async {
    final report = await FilteredReportBuilder(
      _db,
    ).build(filter: filter, generatedAt: DateTime.now());
    final work = report
        .map(
          (row) => PanelWorkItem(
            id: '${row['id']}',
            kind: '${row['kind']}',
            stationNumber: '${row['station_number']}',
            status: '${row['status']}',
            overdue: row['overdue'] == 'да',
            critical: false,
            region: '${row['region']}',
            assigneeId: '${row['assignee_id']}',
          ),
        )
        .toList();
    final stationRows = await _db.db.query('stations');
    final stations = [
      for (final row in stationRows)
        if (actor == null ||
            canReadStation(
              actor,
              OrgStation(
                number: row['number'] as String,
                managementId: row['management_id'] as String?,
                departmentId: row['department_id'] as String?,
                crewId: row['crew_id'] as String?,
                region: row['region'] as String?,
              ),
            ))
          OrgStation(
            number: row['number'] as String,
            managementId: row['management_id'] as String?,
            departmentId: row['department_id'] as String?,
            crewId: row['crew_id'] as String?,
            region: row['region'] as String?,
          ),
    ];
    final auditRows = await _db.db.query(
      'audit_events',
      orderBy: 'created_at DESC',
      limit: 100,
    );
    final audit = [
      for (final row in auditRows)
        if (actor == null ||
            canReadAudit(
              actor,
              eventManagementId: row['management_id'] as String?,
            ))
          AuditRow(
            id: row['id'] as String,
            action: row['action'] as String,
            entityType: row['entity_type'] as String,
            entityId: row['entity_id'] as String,
            createdAt: row['created_at'] as String,
            actorId: row['actor_id'] as String?,
            managementId: row['management_id'] as String?,
          ),
    ];
    final references = await _db.db.query(
      'reference_values',
      orderBy: 'kind, sort_order',
    );
    final users = await _db.db.query('user_profiles', orderBy: 'display_name');
    return PanelSnapshot(
      metrics: summarizePanel(work),
      work: work,
      stations: stations,
      audit: audit,
      directories: [
        for (final row in references)
          DirectoryEntry(
            id: row['id'] as String,
            kind: row['kind'] as String,
            name: row['name'] as String,
            active: (row['active'] as int? ?? 1) == 1,
          ),
      ],
      users: [
        for (final row in users)
          AccessSubject(
            userId: row['user_id'] as String,
            role: appRoleFromCode(row['role'] as String?) ?? AppRole.specialist,
            managementId: row['management_id'] as String?,
            departmentId: row['department_id'] as String?,
            crewId: row['crew_id'] as String?,
            active: (row['active'] as int? ?? 1) == 1,
          ),
      ],
    );
  }
}

class FirestorePanelReader {
  const FirestorePanelReader(this._firestore);

  final FirebaseFirestore _firestore;

  Future<PanelSnapshot> load(PanelFilter filter) async {
    final requests = await _firestore.collection('requests').get();
    final maintenance = await _firestore.collection('maintenance').get();
    final stations = await _firestore.collection('stations').get();
    final audit = await _firestore.collection('audit_events').limit(100).get();
    final users = await _firestore.collection('users').get();
    final references = await _firestore.collection('reference_values').get();
    final work = <PanelWorkItem>[
      for (final doc in requests.docs)
        if (filter.matches(_requestItem(doc.id, doc.data())))
          _requestItem(doc.id, doc.data()),
      for (final doc in maintenance.docs)
        if (filter.matches(_maintenanceItem(doc.id, doc.data())))
          _maintenanceItem(doc.id, doc.data()),
    ];
    return PanelSnapshot(
      metrics: summarizePanel(work),
      work: work,
      stations: [
        for (final doc in stations.docs)
          OrgStation(
            number: doc.id,
            managementId: doc.data()['management_id'] as String?,
            departmentId: doc.data()['department_id'] as String?,
            crewId: doc.data()['crew_id'] as String?,
            region: doc.data()['region'] as String?,
          ),
      ],
      audit: [
        for (final doc in audit.docs)
          AuditRow(
            id: doc.id,
            action: '${doc.data()['action'] ?? ''}',
            entityType: '${doc.data()['entity_type'] ?? ''}',
            entityId: '${doc.data()['entity_id'] ?? ''}',
            createdAt: '${doc.data()['created_at'] ?? ''}',
            actorId: doc.data()['actor_id'] as String?,
            managementId: doc.data()['management_id'] as String?,
          ),
      ],
      directories: [
        for (final doc in references.docs)
          DirectoryEntry(
            id: doc.id,
            kind: '${doc.data()['kind'] ?? ''}',
            name: '${doc.data()['name'] ?? ''}',
            active: doc.data()['active'] != false,
          ),
      ],
      users: [
        for (final doc in users.docs)
          AccessSubject(
            userId: doc.id,
            role:
                appRoleFromCode(doc.data()['role'] as String?) ??
                AppRole.specialist,
            managementId: doc.data()['management_id'] as String?,
            departmentId: doc.data()['department_id'] as String?,
            crewId: doc.data()['crew_id'] as String?,
            active: doc.data()['active'] != false,
          ),
      ],
    );
  }

  PanelWorkItem _requestItem(String id, Map<String, dynamic> data) {
    final status = '${data['workflow_status'] ?? 'created'}';
    return PanelWorkItem(
      id: id,
      kind: 'request',
      stationNumber: '${data['station_number'] ?? ''}',
      status: status,
      overdue: isOverdue(
        dueAt: DateTime.tryParse('${data['due_at'] ?? ''}'),
        workflowStatus: status,
        now: DateTime.now(),
      ),
      critical: data['critical'] == true || data['critical'] == 1,
      region: data['region'] as String?,
      managementId: data['management_id'] as String?,
      departmentId: data['department_id'] as String?,
      crewId: data['crew_id'] as String?,
      assigneeId: data['assignee_id'] as String?,
    );
  }

  PanelWorkItem _maintenanceItem(String id, Map<String, dynamic> data) {
    final status = '${data['workflow_status'] ?? 'planned'}';
    return PanelWorkItem(
      id: id,
      kind: 'maintenance',
      stationNumber: '${data['station_number'] ?? id}',
      status: status,
      overdue: isOverdue(
        dueAt: DateTime.tryParse('${data['due_at'] ?? ''}'),
        workflowStatus: status,
        now: DateTime.now(),
      ),
      critical: false,
      region: data['region'] as String?,
      managementId: data['management_id'] as String?,
      departmentId: data['department_id'] as String?,
      crewId: data['crew_id'] as String?,
      assigneeId: data['assignee_id'] as String?,
    );
  }
}
