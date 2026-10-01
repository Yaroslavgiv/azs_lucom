import 'package:azs_app/core/models/station.dart';
import 'package:azs_app/core/repositories/contract_rule_repository.dart';
import 'package:azs_app/core/repositories/reference_repository.dart';
import 'package:azs_app/core/repositories/request_repository.dart';
import 'package:azs_app/core/repositories/station_repository.dart';
import 'package:azs_app/core/services/geocoder_service.dart';
import 'package:azs_app/core/services/local_work_service.dart';
import 'package:azs_app/core/services/request_exchange.dart';
import 'package:azs_app/core/services/station_creation_service.dart';
import 'package:azs_app/core/services/station_map_status.dart';
import 'package:azs_app/core/services/sync_queue_store.dart';
import 'package:azs_domain/azs_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  const head = AccessSubject(
    userId: 'head',
    role: AppRole.manager,
    scope: ManagerScope.department,
    managementId: 'mgmt',
    departmentId: 'dept',
  );
  const admin = AccessSubject(userId: 'admin', role: AppRole.admin);
  const specialist = AccessSubject(
    userId: 'spec',
    role: AppRole.specialist,
    managementId: 'mgmt',
    departmentId: 'dept',
    crewId: 'crew',
  );

  test(
    'request moves through assignment and keeps one audit on replay',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      await StationRepository(database).upsert(
        Station(
          number: '1',
          name: 'АЗС',
          address: 'Невский',
          region: 'spb',
          managementId: 'mgmt',
          departmentId: 'dept',
          crewId: 'crew',
          specialistId: 'spec',
        ),
      );
      final work = LocalWorkService(database);
      final id = await work.createRequest(
        actor: head,
        stationNumber: '1',
        requestType: 'Ремонт',
        description: 'Не работает ТРК',
      );
      final created = await database.db.query(
        'requests',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(created.single['assignee_id'], 'spec');
      expect(created.single['workflow_status'], 'created');
      final first = await work.applyRequest(
        actor: specialist,
        requestId: id,
        action: WorkAction.start,
      );
      final replay = await work.applyRequest(
        actor: specialist,
        requestId: id,
        action: WorkAction.start,
      );
      expect(first.nextStatus, 'in_progress');
      expect(replay.idempotentReplay, isTrue);
      final audits = await database.db.query(
        'audit_events',
        where: "entity_id = ? AND action = 'start'",
        whereArgs: ['$id'],
      );
      expect(audits, hasLength(1));
      final row = await database.db.query(
        'requests',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(row.single['status'], 'open');
      expect(row.single['workflow_status'], 'in_progress');
    },
  );

  test('return without a comment is stored as a denial', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    await StationRepository(database).upsert(
      Station(
        number: '1',
        name: 'АЗС',
        address: '',
        region: 'spb',
        managementId: 'mgmt',
        departmentId: 'dept',
        crewId: 'crew',
        specialistId: 'spec',
      ),
    );
    final work = LocalWorkService(database);
    final id = await work.createRequest(
      actor: specialist,
      stationNumber: '1',
      requestType: 'Осмотр',
      description: 'Проверка',
    );
    await work.applyRequest(
      actor: specialist,
      requestId: id,
      action: WorkAction.start,
    );
    await work.applyRequest(
      actor: specialist,
      requestId: id,
      action: WorkAction.submit,
      comment: 'Готово',
    );
    expect(
      () => work.applyRequest(
        actor: head,
        requestId: id,
        action: WorkAction.returnForRework,
      ),
      throwsA(isA<WorkDenied>()),
    );
  });

  test('failed external source does not remove local requests', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final requests = RequestRepository(database);
    final id = await requests.add(
      stationNumber: '1',
      requestType: 'Своя',
      description: 'Локальная',
    );
    final exchange = RequestExchange(database, requests);
    final result = await exchange.importNew(_DownSource());
    expect(result.sourceAvailable, isFalse);
    expect(result.imported, 0);
    final rows = await database.db.query(
      'requests',
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(rows.single['description'], 'Локальная');
  });

  test('external import is idempotent', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final exchange = RequestExchange(database, RequestRepository(database));
    const source = _FixedSource();
    await exchange.importNew(source);
    final second = await exchange.importNew(source);
    expect(second.imported, 0);
    final rows = await database.db.query('requests');
    expect(rows, hasLength(1));
    expect(rows.single['source'], 'customer-api');
  });

  test('queue sends the parent before a dependent attachment', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final queue = SyncQueueStore(database);
    await queue.put(entity: 'requests', localPk: '10', operation: 'upsert');
    await queue.put(
      entity: 'attachments',
      localPk: 'file',
      operation: 'upsert',
      dependsOn: 'requests:10',
    );
    expect((await queue.nextBatch()).map((item) => item.localPk), ['10']);
    await queue.remove((await queue.nextBatch()).single.id);
    expect((await queue.nextBatch()).single.localPk, 'file');
  });

  test('repeated push failures stop in the error state', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final queue = SyncQueueStore(database);
    await queue.put(entity: 'requests', localPk: '1', operation: 'upsert');
    final id = (await queue.nextBatch()).single.id;
    for (var attempt = 0; attempt < SyncQueueStore.maxAttempts; attempt++) {
      await queue.recordFailure(id, 'network');
    }
    final row = await database.db.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(row.single['state'], 'error');
    expect(await queue.nextBatch(), isEmpty);
  });

  test(
    'specialist cannot create a station and duplicates are reported',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final stations = StationRepository(database);
      await stations.upsert(
        Station(
          number: '10',
          name: 'Старая',
          address: 'Невский 1',
          region: 'spb',
          lat: 59.9,
          lon: 30.3,
        ),
      );
      final service = StationCreationService(
        stations,
        GeocoderService(stations),
      );
      final denied = await service.create(
        actor: specialist,
        number: '11',
        name: 'Новая',
        address: 'Другой',
        region: 'spb',
        inputMethod: 'coordinates',
        lat: 59.0,
        lon: 30.0,
      );
      expect(denied.saved, isFalse);
      final duplicate = await service.create(
        actor: head,
        number: '10',
        name: 'Копия',
        address: 'Невский 1',
        region: 'spb',
        inputMethod: 'coordinates',
        lat: 59.9,
        lon: 30.3,
      );
      expect(duplicate.saved, isFalse);
      expect(duplicate.warnings, isNotEmpty);
    },
  );

  test('archiving a directory value keeps the row', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final repository = ReferenceRepository(database);
    await repository.upsert(
      kind: 'request_type',
      code: 'repair',
      name: 'Ремонт',
    );
    await repository.archive('request_type:repair');
    final rows = await database.db.query('reference_values');
    expect(rows.single['active'], 0);
    expect(rows.single['name'], 'Ремонт');
  });

  test(
    'manager assigns the station specialist and opens the request',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      await StationRepository(database).upsert(
        Station(
          number: '1',
          name: 'АЗС',
          address: '',
          region: 'spb',
          managementId: 'mgmt',
          departmentId: 'dept',
          crewId: 'crew',
        ),
      );
      await database.db.insert('user_profiles', {
        'user_id': 'spec',
        'display_name': 'Специалист',
        'role': 'specialist',
        'department_id': 'dept',
        'crew_id': 'crew',
        'active': 1,
        'contact': '',
      });
      final work = LocalWorkService(database);
      final id = await work.createRequest(
        actor: head,
        stationNumber: '1',
        requestType: 'Осмотр',
        description: 'Пока без специалиста',
      );
      await work.assignStationSpecialist(
        actor: head,
        stationNumber: '1',
        specialistUserId: 'spec',
      );
      final station = await database.db.query(
        'stations',
        where: 'number = ?',
        whereArgs: ['1'],
      );
      final request = await database.db.query(
        'requests',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(station.single['specialist_id'], 'spec');
      expect(request.single['workflow_status'], 'created');
      expect(request.single['assignee_id'], 'spec');
      expect(
        () => work.assignStationSpecialist(
          actor: specialist,
          stationNumber: '1',
          specialistUserId: 'spec',
        ),
        throwsA(isA<WorkDenied>()),
      );
    },
  );

  test('missing specialist leaves the request unassigned', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    await StationRepository(database).upsert(
      Station(
        number: '1',
        name: 'АЗС',
        address: '',
        region: 'spb',
        managementId: 'mgmt',
        departmentId: 'dept',
        crewId: 'crew',
      ),
    );
    final id = await LocalWorkService(database).createRequest(
      actor: head,
      stationNumber: '1',
      requestType: 'Осмотр',
      description: 'Нет исполнителя',
    );
    final row = await database.db.query(
      'requests',
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(row.single['workflow_status'], 'unassigned');
    expect(row.single['assignee_id'], isNull);
    expect(row.single['due_at'], isNull);
  });

  test('admin publishes a new contract rule version', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final rules = ContractRuleRepository(database);
    await rules.publishVersion(
      actor: admin,
      category: 'repair',
      durationHours: 12,
      requiresReview: false,
    );
    final second = await rules.publishVersion(
      actor: admin,
      category: 'repair',
      durationHours: null,
      requiresReview: true,
    );
    expect(second.version, 2);
    final rows = await database.db.query('contract_rules', where: 'active = 1');
    expect(rows, hasLength(1));
    expect(rows.single['version'], 2);
    expect(rows.single['duration_hours'], isNull);
    expect(
      () => rules.publishVersion(
        actor: specialist,
        category: 'repair',
        durationHours: 1,
        requiresReview: false,
      ),
      throwsA(isA<ContractRuleDenied>()),
    );
  });

  test('contract rule sets the due date and review flag', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    await StationRepository(database).upsert(
      Station(
        number: '1',
        name: 'АЗС',
        address: '',
        region: 'spb',
        managementId: 'mgmt',
        departmentId: 'dept',
        crewId: 'crew',
        specialistId: 'spec',
      ),
    );
    await database.db.insert('contract_rules', {
      'id': 'repair-1',
      'category': 'repair',
      'duration_hours': 24,
      'requires_review': 1,
      'effective_from': '2020-01-01T00:00:00.000Z',
      'version': 1,
      'active': 1,
    });
    final work = LocalWorkService(
      database,
      clock: () => DateTime.utc(2026, 10, 1, 12),
    );
    final id = await work.createRequest(
      actor: head,
      stationNumber: '1',
      requestType: 'Ремонт',
      description: 'По договору',
      category: 'repair',
    );
    final row = await database.db.query(
      'requests',
      where: 'id = ?',
      whereArgs: [id],
    );
    expect(row.single['requires_review'], 1);
    expect(row.single['due_at'], isNotNull);
    expect(
      () => work.applyRequest(
        actor: specialist,
        requestId: id,
        action: WorkAction.complete,
      ),
      throwsA(isA<WorkDenied>()),
    );
  });

  test('past month becomes overdue and keeps the map red', () async {
    final clock = DateTime.utc(2026, 9, 30, 21, 30);
    final database = await openTestDatabase();
    addTearDown(database.close);
    await StationRepository(database).upsert(
      Station(
        number: '1',
        name: 'АЗС',
        address: '',
        region: 'spb',
        managementId: 'mgmt',
        departmentId: 'dept',
        crewId: 'crew',
        specialistId: 'spec',
      ),
    );
    await database.db.insert('maintenance', {
      'station_number': '1',
      'month': '2026-09',
      'status': 'pending',
      'workflow_status': 'not_done',
    });
    final work = LocalWorkService(database, clock: () => clock);
    await work.rollMaintenanceMonths();
    final past = await database.db.query(
      'maintenance',
      where: 'month = ?',
      whereArgs: ['2026-09'],
    );
    expect(past.single['workflow_status'], 'overdue');
    await work.applyMaintenance(
      actor: specialist,
      stationNumber: '1',
      month: '2026-10',
      action: WorkAction.complete,
    );
    final tones = await StationMapStatusService(
      database,
      clock: () => clock,
    ).load();
    expect(tones['1'], MapTone.attention);
  });

  test('workflow tables exist in a fresh database', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final tables = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll([
        'managements',
        'departments',
        'crews',
        'user_profiles',
        'checklist_templates',
        'contract_rules',
        'attachments',
        'audit_events',
        'notifications',
      ]),
    );
    final template = await database.db.query('checklist_templates');
    expect(template, isNotEmpty);
  });
}

class _DownSource implements RequestSource {
  @override
  String get sourceId => 'customer-api';

  @override
  Future<List<ExternalRequest>> fetchChanges({DateTime? since}) async {
    throw StateError('password=secret source down');
  }
}

class _FixedSource implements RequestSource {
  const _FixedSource();

  @override
  String get sourceId => 'customer-api';

  @override
  Future<List<ExternalRequest>> fetchChanges({DateTime? since}) async {
    return const [
      ExternalRequest(
        externalId: 'ext-1',
        stationNumber: '1',
        description: 'Из источника',
      ),
    ];
  }
}
