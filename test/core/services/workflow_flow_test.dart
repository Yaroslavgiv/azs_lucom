import 'package:azs_app/core/models/station.dart';
import 'package:azs_app/core/repositories/reference_repository.dart';
import 'package:azs_app/core/repositories/request_repository.dart';
import 'package:azs_app/core/repositories/station_repository.dart';
import 'package:azs_app/core/services/geocoder_service.dart';
import 'package:azs_app/core/services/local_work_service.dart';
import 'package:azs_app/core/services/request_exchange.dart';
import 'package:azs_app/core/services/station_creation_service.dart';
import 'package:azs_app/core/services/sync_queue_store.dart';
import 'package:azs_domain/azs_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  const head = AccessSubject(
    userId: 'head',
    role: AppRole.departmentHead,
    managementId: 'mgmt',
    departmentId: 'dept',
  );
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
        ),
      );
      final work = LocalWorkService(database);
      final id = await work.createRequest(
        actor: head,
        stationNumber: '1',
        requestType: 'Ремонт',
        description: 'Не работает ТРК',
      );
      await work.applyRequest(
        actor: head,
        requestId: id,
        action: WorkAction.assign,
        assigneeId: 'spec',
      );
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
      actor: head,
      requestId: id,
      action: WorkAction.assign,
      assigneeId: 'spec',
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
