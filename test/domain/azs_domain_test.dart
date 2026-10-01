import 'package:azs_domain/azs_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const station = OrgStation(
    number: '1',
    managementId: 'mgmt',
    departmentId: 'dept',
    crewId: 'crew',
    region: 'spb',
  );
  const specialist = AccessSubject(
    userId: 'spec',
    role: AppRole.specialist,
    managementId: 'mgmt',
    departmentId: 'dept',
    crewId: 'crew',
  );
  const otherSpecialist = AccessSubject(
    userId: 'other',
    role: AppRole.specialist,
    managementId: 'mgmt',
    departmentId: 'dept',
    crewId: 'other-crew',
  );
  const departmentHead = AccessSubject(
    userId: 'head',
    role: AppRole.manager,
    scope: ManagerScope.department,
    managementId: 'mgmt',
    departmentId: 'dept',
  );
  const managementHead = AccessSubject(
    userId: 'boss',
    role: AppRole.manager,
    scope: ManagerScope.management,
    managementId: 'mgmt',
  );
  const foreignHead = AccessSubject(
    userId: 'foreign',
    role: AppRole.manager,
    scope: ManagerScope.management,
    managementId: 'other',
  );
  const admin = AccessSubject(userId: 'admin', role: AppRole.admin);

  group('request transitions', () {
    test('manual assignment is denied', () {
      final result = applyWorkCommand(
        actor: departmentHead,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'created',
        action: WorkAction.assign,
        commandKey: 'k1',
        assigneeId: 'spec',
      );
      expect(result.denial, 'Назначение вручную недоступно');
    });

    test('assignee closes a request without review', () {
      final result = applyWorkCommand(
        actor: specialist,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'created',
        action: WorkAction.complete,
        commandKey: 'close',
        assigneeId: 'spec',
      );
      expect(result.nextStatus, 'closed');
      expect(legacyRequestStatus('closed'), 'closed');
    });

    test('review rule blocks direct completion', () {
      final result = applyWorkCommand(
        actor: specialist,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'in_progress',
        action: WorkAction.complete,
        commandKey: 'close-review',
        assigneeId: 'spec',
        requiresReview: true,
      );
      expect(result.denial, 'Заявка требует проверки руководителя');
    });

    test('specialist cannot assign', () {
      final result = applyWorkCommand(
        actor: specialist,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'created',
        action: WorkAction.assign,
        commandKey: 'k1',
        assigneeId: 'spec',
      );
      expect(result.succeeded, isFalse);
    });

    test('assignee starts and submits', () {
      final started = applyWorkCommand(
        actor: specialist,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'assigned',
        action: WorkAction.start,
        commandKey: 'k2',
        assigneeId: 'spec',
      );
      expect(started.nextStatus, 'in_progress');
      final submitted = applyWorkCommand(
        actor: specialist,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'in_progress',
        action: WorkAction.submit,
        commandKey: 'k3',
        assigneeId: 'spec',
      );
      expect(submitted.nextStatus, 'on_review');
    });

    test('return without comment is denied', () {
      final result = applyWorkCommand(
        actor: departmentHead,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'on_review',
        action: WorkAction.returnForRework,
        commandKey: 'k4',
        comment: '   ',
      );
      expect(result.denial, 'Возврат требует комментарий');
    });

    test('return with comment and accept', () {
      final returned = applyWorkCommand(
        actor: departmentHead,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'on_review',
        action: WorkAction.returnForRework,
        commandKey: 'k4',
        comment: 'Добавьте фото',
      );
      expect(returned.nextStatus, 'returned');
      final accepted = applyWorkCommand(
        actor: departmentHead,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'on_review',
        action: WorkAction.accept,
        commandKey: 'k5',
      );
      expect(accepted.nextStatus, 'accepted');
    });

    test('repeated accept is idempotent and does not change status', () {
      final result = applyWorkCommand(
        actor: departmentHead,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'accepted',
        action: WorkAction.accept,
        commandKey: 'k6',
      );
      expect(result.idempotentReplay, isTrue);
      expect(result.nextStatus, 'accepted');
    });

    test('same command key is a replay', () {
      final result = applyWorkCommand(
        actor: departmentHead,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'assigned',
        action: WorkAction.start,
        commandKey: 'same',
        lastCommandKey: 'same',
        assigneeId: 'spec',
      );
      expect(result.idempotentReplay, isTrue);
      expect(result.applied, isFalse);
    });

    test('admin cannot accept operational work', () {
      final result = applyWorkCommand(
        actor: admin,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'on_review',
        action: WorkAction.accept,
        commandKey: 'k7',
      );
      expect(result.succeeded, isFalse);
    });

    test('foreign management cannot see the station', () {
      final result = applyWorkCommand(
        actor: foreignHead,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'created',
        action: WorkAction.assign,
        commandKey: 'k8',
        assigneeId: 'spec',
      );
      expect(result.denial, 'Нет доступа к объекту');
    });

    test('another specialist cannot execute the assignment', () {
      final result = applyWorkCommand(
        actor: otherSpecialist,
        station: station,
        kind: WorkKind.request,
        currentStatus: 'assigned',
        action: WorkAction.start,
        commandKey: 'k9',
        assigneeId: 'spec',
        assignedToActor: true,
      );
      expect(result.succeeded, isFalse);
    });

    test('specialist records maintenance in one action', () {
      final result = applyWorkCommand(
        actor: specialist,
        station: station,
        kind: WorkKind.maintenance,
        currentStatus: 'not_done',
        action: WorkAction.complete,
        commandKey: 'k10',
        assigneeId: 'spec',
      );
      expect(result.nextStatus, 'done');
      final again = applyWorkCommand(
        actor: specialist,
        station: station,
        kind: WorkKind.maintenance,
        currentStatus: 'done',
        action: WorkAction.complete,
        commandKey: 'k11',
        assigneeId: 'spec',
      );
      expect(again.idempotentReplay, isTrue);
    });

    test('accepted request stays closed in the legacy status', () {
      expect(legacyRequestStatus('accepted'), 'closed');
      expect(legacyRequestStatus('created'), 'open');
      expect(legacyMaintenanceStatus('done'), 'done');
      expect(legacyMaintenanceStatus('not_done'), 'pending');
    });

    test('legacy head codes decode as a manager scope', () {
      expect(appRoleFromCode('department_head'), AppRole.manager);
      expect(decodeRole('department_head')?.scope, ManagerScope.department);
      expect(decodeRole('management_head')?.scope, ManagerScope.management);
      expect(contractualDueAt(DateTime.utc(2026, 1, 1), null), isNull);
      expect(
        contractualDueAt(DateTime.utc(2026, 1, 1), 48),
        DateTime.utc(2026, 1, 3),
      );
    });
  });

  group('access', () {
    test('department head sees every crew of the department', () {
      expect(canReadStation(departmentHead, station), isTrue);
      expect(
        canReadStation(
          departmentHead,
          const OrgStation(
            number: '2',
            managementId: 'mgmt',
            departmentId: 'dept',
            crewId: 'crew-b',
          ),
        ),
        isTrue,
      );
      expect(
        canReadStation(
          departmentHead,
          const OrgStation(
            number: '3',
            managementId: 'mgmt',
            departmentId: 'other',
            crewId: 'crew',
          ),
        ),
        isFalse,
      );
    });

    test('management head sees subordinate departments only', () {
      expect(canReadStation(managementHead, station), isTrue);
      expect(canReadStation(foreignHead, station), isFalse);
    });

    test('specialist sees the assigned station, not the whole crew', () {
      expect(canReadStation(specialist, station), isTrue);
      expect(
        canReadStation(
          specialist,
          const OrgStation(
            number: '8',
            managementId: 'mgmt',
            departmentId: 'dept',
            crewId: 'crew',
            specialistId: 'other',
          ),
        ),
        isFalse,
      );
      expect(
        canReadStation(
          specialist,
          const OrgStation(
            number: '9',
            managementId: 'mgmt',
            departmentId: 'dept',
            crewId: 'crew-b',
          ),
        ),
        isFalse,
      );
      expect(
        canReadStation(
          specialist,
          const OrgStation(
            number: '9',
            managementId: 'mgmt',
            departmentId: 'dept',
            crewId: 'crew-b',
          ),
          assignedToActor: true,
        ),
        isTrue,
      );
    });

    test('crew change inside the department is allowed', () {
      expect(
        canReassignCrew(
          actor: departmentHead,
          station: station,
          targetManagementId: 'mgmt',
          targetDepartmentId: 'dept',
          targetCrewId: 'crew-b',
        ),
        isTrue,
      );
    });

    test('move between departments is blocked', () {
      expect(
        canReassignCrew(
          actor: managementHead,
          station: station,
          targetManagementId: 'mgmt',
          targetDepartmentId: 'other-dept',
          targetCrewId: 'crew-b',
        ),
        isFalse,
      );
    });

    test('department manager can assign the station specialist', () {
      expect(canAssignStationSpecialist(departmentHead, station), isTrue);
      expect(canAssignStationSpecialist(specialist, station), isFalse);
      expect(canAssignStationSpecialist(foreignHead, station), isFalse);
    });

    test('specialist cannot create a station or read audit', () {
      expect(canCreateStation(specialist), isFalse);
      expect(canCreateStation(departmentHead), isTrue);
      expect(canReadAudit(specialist, eventManagementId: 'mgmt'), isFalse);
      expect(canReadAudit(admin, eventManagementId: 'mgmt'), isTrue);
      expect(canReadAudit(departmentHead, eventManagementId: 'mgmt'), isTrue);
      expect(canReadAudit(departmentHead, eventManagementId: 'other'), isFalse);
    });
  });

  group('map tone', () {
    test('previous overdue maintenance overrides this month', () {
      expect(
        resolveMapTone(
          const MapStatusInput(
            maintenanceDoneThisMonth: true,
            previousPeriodOverdue: true,
          ),
        ),
        MapTone.attention,
      );
      expect(
        resolveMapTone(
          const MapStatusInput(
            maintenanceDoneThisMonth: true,
            contractualOverdueOrCritical: true,
          ),
        ),
        MapTone.attention,
      );
    });

    test('this month done is green when nothing is overdue', () {
      expect(
        resolveMapTone(const MapStatusInput(maintenanceDoneThisMonth: true)),
        MapTone.done,
      );
    });

    test('otherwise the station stays not done', () {
      final tone = resolveMapTone(
        const MapStatusInput(maintenanceDoneThisMonth: false),
      );
      expect(tone, MapTone.planned);
      expect(mapToneLabel(tone), 'ТО не выполнено');
      expect(mapToneLabel(MapTone.attention), 'Просрочено');
      expect(mapToneLabel(MapTone.done), 'ТО выполнено');
    });
  });

  group('stations, checklist, panel, logs', () {
    test('rejects coordinates outside the valid range', () {
      expect(validateCoordinates(91, 30), isNotNull);
      expect(validateCoordinates(59.9, 181), isNotNull);
      expect(validateCoordinates(59.9, 30.3), isNull);
    });

    test('warns about number, address and nearby coordinates', () {
      final warnings = findDuplicateWarnings(
        draft: const StationIdentity(
          number: '10',
          address: 'Невский 1',
          lat: 59.9,
          lon: 30.3,
        ),
        existing: const [
          StationIdentity(number: '10', address: 'другой', lat: 0, lon: 0),
          StationIdentity(
            number: '11',
            address: 'невский   1',
            lat: 10,
            lon: 10,
          ),
          StationIdentity(
            number: '12',
            address: 'далеко',
            lat: 59.9,
            lon: 30.3,
          ),
        ],
      );
      expect(warnings, hasLength(3));
    });

    test('required checklist item blocks submit', () {
      expect(
        checklistReadyForSubmit(const [
          ChecklistItemDraft(id: 'a', required: true, result: 'ok'),
          ChecklistItemDraft(id: 'b', required: false),
        ]),
        isTrue,
      );
      expect(
        checklistReadyForSubmit(const [
          ChecklistItemDraft(id: 'a', required: true),
        ]),
        isFalse,
      );
    });

    test('panel filter and metrics use the same slice', () {
      final items = [
        PanelWorkItem(
          id: 'r1',
          kind: 'request',
          stationNumber: '1',
          status: 'assigned',
          overdue: true,
          critical: false,
          crewId: 'crew',
          region: 'spb',
        ),
        PanelWorkItem(
          id: 'r2',
          kind: 'request',
          stationNumber: '2',
          status: 'accepted',
          overdue: false,
          critical: false,
          crewId: 'other',
          region: 'novgorod',
        ),
        const PanelWorkItem(
          id: 'm1',
          kind: 'maintenance',
          stationNumber: '1',
          status: 'on_review',
          overdue: false,
          critical: false,
          crewId: 'crew',
        ),
      ];
      const filter = PanelFilter(crewId: 'crew');
      final visible = items.where(filter.matches).toList();
      final metrics = summarizePanel(visible);
      expect(visible.map((item) => item.id), ['r1', 'm1']);
      expect(metrics.openRequests, 1);
      expect(metrics.overdueRequests, 1);
      expect(metrics.attentionStations, 1);
      expect(metrics.maintenanceWaitingAcceptance, 1);
    });

    test('overdue uses the supplied deadline and ignores closed work', () {
      final due = DateTime.utc(2026, 9, 1);
      expect(
        isOverdue(
          dueAt: due,
          workflowStatus: 'assigned',
          now: DateTime.utc(2026, 9, 2),
        ),
        isTrue,
      );
      expect(
        isOverdue(
          dueAt: due,
          workflowStatus: 'accepted',
          now: DateTime.utc(2026, 9, 2),
        ),
        isFalse,
      );
    });

    test('redacts secrets from logs', () {
      final text = redactLog(
        'Authorization: Bearer secret-token password=qwerty eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.signature',
      );
      expect(text.contains('secret-token'), isFalse);
      expect(text.contains('qwerty'), isFalse);
      expect(text.contains('eyJ'), isFalse);
    });

    test('notification key is stable', () {
      expect(
        notificationEventKey(
          event: 'assigned',
          entityId: 'r1',
          recipientId: 'spec',
        ),
        notificationEventKey(
          event: 'assigned',
          entityId: 'r1',
          recipientId: 'spec',
        ),
      );
    });
  });
}
