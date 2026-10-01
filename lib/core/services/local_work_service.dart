import 'dart:convert';

import 'package:azs_domain/azs_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../repositories/profile_repository.dart';
import 'ids.dart';
import 'sync_change_publisher.dart';

class WorkDenied implements Exception {
  WorkDenied(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalWorkService {
  LocalWorkService(
    this._db, {
    SyncChangePublisher? sync,
    DateTime Function()? clock,
  }) : _sync = sync,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SyncChangePublisher? _sync;
  final DateTime Function() _clock;

  Future<int> createRequest({
    required AccessSubject actor,
    required String stationNumber,
    required String requestType,
    required String description,
    String category = '',
    bool critical = false,
  }) async {
    final station = await _station(stationNumber);
    if (!canReadStation(actor, station)) {
      throw WorkDenied('Нет доступа к объекту');
    }
    final createdAt = _clock().toUtc();
    final rule = await _contractRule(category);
    final due = contractualDueAt(createdAt, rule?.durationHours);
    final specialistId = station.specialistId;
    final missingSpecialist = specialistId == null || specialistId.isEmpty;
    final workflow = missingSpecialist ? 'unassigned' : 'created';
    final id = await _db.db.insert('requests', {
      'station_number': stationNumber,
      'type': 'НЗ',
      'request_type': requestType,
      'description': description,
      'date_created': createdAt.toIso8601String().substring(0, 10),
      'status': 'open',
      'uuid': newUuid(),
      'category': category,
      'author_id': actor.userId,
      'assignee_id': missingSpecialist ? null : specialistId,
      'due_at': due?.toIso8601String(),
      'critical': critical ? 1 : 0,
      'revision': 0,
      'workflow_status': workflow,
      'requires_review': rule?.requiresReview == true ? 1 : 0,
      'source': 'internal',
      'management_id': station.managementId,
      'department_id': station.departmentId,
      'crew_id': station.crewId,
    });
    await _publishEntity(SyncEntity.requests, '$id');
    await _audit(
      actor: actor,
      station: station,
      entityType: 'request',
      entityId: '$id',
      action: 'create',
      nextValue: workflow,
    );
    if (missingSpecialist) {
      final leaders = await ProfileRepository(_db).leadersInScope(station);
      await _notifyUsers(
        recipients: leaders.map((leader) => leader.userId),
        actor: actor,
        type: 'missing_specialist',
        title: 'На станции нет специалиста',
        entityType: 'request',
        entityId: '$id',
        station: station,
      );
    } else {
      await _notifyUsers(
        recipients: [specialistId],
        actor: actor,
        type: 'request_created',
        title: 'Новая заявка на вашей АЗС',
        entityType: 'request',
        entityId: '$id',
        station: station,
      );
    }
    return id;
  }

  Future<WorkCommandResult> applyRequest({
    required AccessSubject actor,
    required int requestId,
    required WorkAction action,
    String? comment,
    String? dueAt,
  }) async {
    final rows = await _db.db.query(
      'requests',
      where: 'id = ?',
      whereArgs: [requestId],
      limit: 1,
    );
    if (rows.isEmpty) throw WorkDenied('Заявка не найдена');
    final row = rows.first;
    final station = await _station(row['station_number'] as String);
    final currentAssignee = row['assignee_id'] as String?;
    final requiresReview = (row['requires_review'] as int? ?? 0) == 1;
    final revision = (row['revision'] as int?) ?? 0;
    final commandKey = workCommandKey(
      entity: 'request',
      localId: '$requestId',
      action: action.name,
      revision: revision,
    );
    final result = applyWorkCommand(
      actor: actor,
      station: station,
      kind: WorkKind.request,
      currentStatus: (row['workflow_status'] as String?) ?? 'created',
      action: action,
      commandKey: commandKey,
      lastCommandKey: row['last_command_key'] as String?,
      comment: comment,
      assigneeId: currentAssignee,
      assignedToActor: currentAssignee == actor.userId,
      requiresReview: requiresReview,
    );
    if (!result.succeeded) {
      throw WorkDenied(result.denial ?? 'Переход недоступен');
    }
    if (result.idempotentReplay) return result;

    final next = result.nextStatus!;
    final closed =
        next == 'accepted' || next == 'cancelled' || next == 'closed';
    await _db.db.update(
      'requests',
      {
        'workflow_status': next,
        'status': legacyRequestStatus(next),
        'assignee_id': currentAssignee,
        'due_at': dueAt ?? row['due_at'],
        'revision': revision + 1,
        'last_command_key': commandKey,
        'close_comment': action == WorkAction.returnForRework
            ? comment
            : row['close_comment'],
        'close_date': closed ? _clock().toIso8601String() : row['close_date'],
        'result_text':
            action == WorkAction.submit || action == WorkAction.complete
            ? (comment ?? row['result_text'])
            : row['result_text'],
      },
      where: 'id = ?',
      whereArgs: [requestId],
    );
    if (comment != null && comment.trim().isNotEmpty) {
      await _db.db.insert('comments', {
        'id': newUuid(),
        'entity_type': 'request',
        'entity_id': '$requestId',
        'body': comment.trim(),
        'purpose': action.name,
        'author_id': actor.userId,
        'created_at': _clock().toIso8601String(),
      });
    }
    await _audit(
      actor: actor,
      station: station,
      entityType: 'request',
      entityId: '$requestId',
      action: action.name,
      previousValue: row['workflow_status'] as String?,
      nextValue: next,
    );
    await _notifyFor(
      action: action,
      entityType: 'request',
      entityId: '$requestId',
      station: station,
      assigneeId: currentAssignee,
      actor: actor,
    );
    await _enqueueCommand(
      kind: 'request',
      localId: '$requestId',
      action: action,
      commandKey: commandKey,
      revision: revision,
      assigneeId: currentAssignee,
      dueAt: dueAt ?? row['due_at'] as String?,
      comment: comment,
      dependsOn: 'requests:$requestId',
    );
    return result;
  }

  Future<void> ensureMaintenance({
    required String stationNumber,
    required String month,
    String? regulationId,
    String? dueAt,
  }) async {
    final station = await _station(stationNumber);
    await _db.db.insert('maintenance', {
      'station_number': stationNumber,
      'month': month,
      'status': 'pending',
      'workflow_status': 'not_done',
      'assignee_id': station.specialistId,
      'uuid': newUuid(),
      'regulation_id': regulationId,
      'due_at': dueAt,
      'revision': 0,
      'management_id': station.managementId,
      'department_id': station.departmentId,
      'crew_id': station.crewId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<WorkCommandResult> applyMaintenance({
    required AccessSubject actor,
    required String stationNumber,
    required String month,
    required WorkAction action,
    String? comment,
    String? dueAt,
  }) async {
    await ensureMaintenance(stationNumber: stationNumber, month: month);
    final rows = await _db.db.query(
      'maintenance',
      where: 'station_number = ? AND month = ?',
      whereArgs: [stationNumber, month],
      limit: 1,
    );
    final row = rows.first;
    final station = await _station(stationNumber);
    final revision = (row['revision'] as int?) ?? 0;
    final localId = '${stationNumber}_$month';
    final commandKey = workCommandKey(
      entity: 'maintenance',
      localId: localId,
      action: action.name,
      revision: revision,
    );
    final currentAssignee =
        (row['assignee_id'] as String?) ?? station.specialistId;
    final result = applyWorkCommand(
      actor: actor,
      station: station,
      kind: WorkKind.maintenance,
      currentStatus: (row['workflow_status'] as String?) ?? 'not_done',
      action: action,
      commandKey: commandKey,
      lastCommandKey: row['last_command_key'] as String?,
      comment: comment,
      assigneeId: currentAssignee,
      assignedToActor: currentAssignee == actor.userId,
    );
    if (!result.succeeded) {
      throw WorkDenied(result.denial ?? 'Переход недоступен');
    }
    if (result.idempotentReplay) return result;
    final next = result.nextStatus!;
    await _db.db.update(
      'maintenance',
      {
        'workflow_status': next,
        'status': legacyMaintenanceStatus(next),
        'assignee_id': currentAssignee,
        'due_at': dueAt ?? row['due_at'],
        'revision': revision + 1,
        'last_command_key': commandKey,
        'accepted_at': next == 'done' || next == 'accepted'
            ? _clock().toIso8601String()
            : row['accepted_at'],
        'date_done': next == 'done' || next == 'accepted'
            ? _clock().toIso8601String()
            : row['date_done'],
        'result_text': comment ?? row['result_text'],
      },
      where: 'station_number = ? AND month = ?',
      whereArgs: [stationNumber, month],
    );
    await _audit(
      actor: actor,
      station: station,
      entityType: 'maintenance',
      entityId: localId,
      action: action.name,
      previousValue: row['workflow_status'] as String?,
      nextValue: next,
    );
    await _notifyFor(
      action: action,
      entityType: 'maintenance',
      entityId: localId,
      station: station,
      assigneeId: currentAssignee,
      actor: actor,
    );
    await _enqueueCommand(
      kind: 'maintenance',
      localId: localId,
      action: action,
      commandKey: commandKey,
      revision: revision,
      assigneeId: currentAssignee,
      dueAt: dueAt ?? row['due_at'] as String?,
      comment: comment,
      dependsOn: 'maintenance:$localId',
    );
    return result;
  }

  Future<void> saveChecklistResult({
    required AccessSubject actor,
    required String maintenanceKey,
    required String itemId,
    required String result,
    String? comment,
    String? equipmentId,
  }) async {
    await _db.db.insert('checklist_results', {
      'id': '$maintenanceKey:$itemId',
      'maintenance_key': maintenanceKey,
      'item_id': itemId,
      'result': result,
      'comment': comment,
      'equipment_id': equipmentId,
      'author_id': actor.userId,
      'updated_at': _clock().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> reassignCrew({
    required AccessSubject actor,
    required String stationNumber,
    required String targetCrewId,
  }) async {
    final station = await _station(stationNumber);
    final crewRows = await _db.db.query(
      'crews',
      where: 'id = ?',
      whereArgs: [targetCrewId],
      limit: 1,
    );
    if (crewRows.isEmpty) throw WorkDenied('Бригада не найдена');
    final departmentId = crewRows.first['department_id'] as String?;
    final departmentRows = await _db.db.query(
      'departments',
      where: 'id = ?',
      whereArgs: [departmentId],
      limit: 1,
    );
    final managementId = departmentRows.isEmpty
        ? null
        : departmentRows.first['management_id'] as String?;
    if (!canReassignCrew(
      actor: actor,
      station: station,
      targetManagementId: managementId,
      targetDepartmentId: departmentId,
      targetCrewId: targetCrewId,
    )) {
      throw WorkDenied('Перевод станции за пределы отдела запрещён');
    }
    final now = _clock().toIso8601String();
    await _db.db.update(
      'stations',
      {
        'crew_id': targetCrewId,
        'department_id': departmentId,
        'management_id': managementId,
      },
      where: 'number = ?',
      whereArgs: [stationNumber],
    );
    await _db.db.insert('station_assignment_history', {
      'station_number': stationNumber,
      'previous_crew_id': station.crewId,
      'new_crew_id': targetCrewId,
      'previous_department_id': station.departmentId,
      'new_department_id': departmentId,
      'author_id': actor.userId,
      'changed_at': now,
    });
    await _audit(
      actor: actor,
      station: station,
      entityType: 'station',
      entityId: stationNumber,
      action: 'reassign_crew',
      previousValue: station.crewId,
      nextValue: targetCrewId,
    );
    await _enqueueCommand(
      kind: 'station',
      localId: stationNumber,
      action: WorkAction.reassign,
      commandKey: workCommandKey(
        entity: 'station',
        localId: stationNumber,
        action: 'reassign_crew',
        revision: now.hashCode,
      ),
      revision: 0,
      assigneeId: targetCrewId,
      comment: 'crew',
      dependsOn: 'stations:$stationNumber',
    );
    return true;
  }

  Future<void> rollMaintenanceMonths() async {
    final current = moscowServiceMonth(_clock());
    final stations = await _db.db.query('stations');
    for (final stationRow in stations) {
      final number = stationRow['number'] as String;
      final station = _stationFromRow(stationRow);
      final rows = await _db.db.query(
        'maintenance',
        where: 'station_number = ?',
        whereArgs: [number],
      );
      var hasCurrent = false;
      for (final row in rows) {
        final month = row['month'] as String? ?? '';
        if (month == current.key) {
          hasCurrent = true;
          continue;
        }
        if (!isEarlierServiceMonth(month, current)) continue;
        final workflow = row['workflow_status'] as String? ?? 'planned';
        final legacy = row['status'] as String?;
        if (maintenanceCountsAsDone(workflow, legacy) ||
            workflow == 'overdue') {
          continue;
        }
        await _db.db.update(
          'maintenance',
          {'workflow_status': 'overdue', 'status': 'pending'},
          where: 'station_number = ? AND month = ?',
          whereArgs: [number, month],
        );
        final leaders = await ProfileRepository(_db).leadersInScope(station);
        await _notifyUsers(
          recipients: leaders.map((leader) => leader.userId),
          type: 'maintenance_overdue',
          title: 'ТО не выполнено к концу месяца',
          entityType: 'maintenance',
          entityId: '${number}_$month',
          station: station,
        );
      }
      if (!hasCurrent && (stationRow['active'] as int? ?? 1) == 1) {
        await ensureMaintenance(stationNumber: number, month: current.key);
      }
    }
    await _notifyRequestDeadlines();
  }

  Future<List<Map<String, Object?>>> checklistTemplateItems() async {
    final rows = await _db.db.query(
      'checklist_templates',
      where: 'active = 1',
      orderBy: 'version DESC',
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    final raw = rows.first['items_json'] as String? ?? '[]';
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map(Map<String, Object?>.from).toList();
  }

  Future<OrgStation> _station(String number) async {
    final rows = await _db.db.query(
      'stations',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    if (rows.isEmpty) {
      return OrgStation(number: number);
    }
    final row = rows.first;
    return _stationFromRow(row);
  }

  OrgStation _stationFromRow(Map<String, Object?> row) {
    return OrgStation(
      number: row['number'] as String,
      managementId: row['management_id'] as String?,
      departmentId: row['department_id'] as String?,
      crewId: row['crew_id'] as String?,
      region: row['region'] as String?,
      specialistId: row['specialist_id'] as String?,
    );
  }

  Future<ContractRule?> _contractRule(String category) async {
    if (category.isEmpty) return null;
    final rows = await _db.db.query(
      'contract_rules',
      where: 'category = ? AND active = 1',
      whereArgs: [category],
      orderBy: 'version DESC, effective_from DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final effective = DateTime.tryParse(
      (row['effective_from'] as String?) ?? '',
    );
    if (effective != null && effective.isAfter(_clock().toUtc())) return null;
    return ContractRule(
      category: category,
      version: (row['version'] as int?) ?? 1,
      durationHours: row['duration_hours'] as int?,
      requiresReview: (row['requires_review'] as int? ?? 0) == 1,
      active: true,
    );
  }

  Future<void> _notifyRequestDeadlines() async {
    final now = _clock().toUtc();
    final soon = now.add(const Duration(hours: 24));
    final rows = await _db.db.query('requests');
    for (final row in rows) {
      final workflow = (row['workflow_status'] as String?) ?? 'created';
      final due = DateTime.tryParse((row['due_at'] as String?) ?? '');
      final station = await _station(row['station_number'] as String);
      final entityId = '${row['id']}';
      if (isOverdue(dueAt: due, workflowStatus: workflow, now: now)) {
        final leaders = await ProfileRepository(_db).leadersInScope(station);
        await _notifyUsers(
          recipients: leaders.map((leader) => leader.userId),
          type: 'request_overdue',
          title: 'Просрочена заявка',
          entityType: 'request',
          entityId: entityId,
          station: station,
        );
        continue;
      }
      final assignee = row['assignee_id'] as String?;
      if (due != null &&
          assignee != null &&
          !due.isAfter(soon) &&
          due.isAfter(now)) {
        await _notifyUsers(
          recipients: [assignee],
          type: 'deadline_soon',
          title: 'Приближается договорный срок заявки',
          entityType: 'request',
          entityId: entityId,
          station: station,
        );
      }
    }
  }

  Future<void> _notifyUsers({
    required Iterable<String> recipients,
    required String type,
    required String title,
    required String entityType,
    required String entityId,
    required OrgStation station,
    AccessSubject? actor,
  }) async {
    final unique = recipients.toSet()..remove(actor?.userId);
    for (final recipient in unique) {
      if (recipient.isEmpty) continue;
      await _db.db.insert('notifications', {
        'id': newUuid(),
        'recipient_id': recipient,
        'event_key': notificationEventKey(
          event: type,
          entityId: entityId,
          recipientId: recipient,
        ),
        'type': type,
        'entity_type': entityType,
        'entity_id': entityId,
        'title': title,
        'body': station.number,
        'created_at': _clock().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _audit({
    required AccessSubject actor,
    required OrgStation station,
    required String entityType,
    required String entityId,
    required String action,
    String? previousValue,
    String? nextValue,
  }) async {
    await _db.db.insert('audit_events', {
      'id': newUuid(),
      'actor_id': actor.userId,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'previous_value': previousValue,
      'new_value': nextValue,
      'created_at': _clock().toIso8601String(),
      'management_id': station.managementId,
    });
  }

  Future<void> _notifyFor({
    required WorkAction action,
    required String entityType,
    required String entityId,
    required OrgStation station,
    required AccessSubject actor,
    String? assigneeId,
  }) async {
    final recipients = <String>{};
    if (action == WorkAction.assign ||
        action == WorkAction.reassign ||
        action == WorkAction.returnForRework) {
      if (assigneeId != null) recipients.add(assigneeId);
    }
    if (action == WorkAction.submit) {
      final leaders = await ProfileRepository(_db).leadersInScope(station);
      recipients.addAll(leaders.map((leader) => leader.userId));
    }
    recipients.remove(actor.userId);
    for (final recipient in recipients) {
      final eventKey = notificationEventKey(
        event: action.name,
        entityId: entityId,
        recipientId: recipient,
      );
      await _db.db.insert('notifications', {
        'id': newUuid(),
        'recipient_id': recipient,
        'event_key': eventKey,
        'type': action.name,
        'entity_type': entityType,
        'entity_id': entityId,
        'title': _notificationTitle(action),
        'body': station.number,
        'created_at': _clock().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  String _notificationTitle(WorkAction action) {
    switch (action) {
      case WorkAction.assign:
      case WorkAction.reassign:
        return 'Назначена работа';
      case WorkAction.returnForRework:
        return 'Отчёт возвращён на доработку';
      case WorkAction.submit:
        return 'Результат отправлен на проверку';
      case WorkAction.accept:
        return 'Работа принята';
      case WorkAction.complete:
        return 'Работа завершена';
      default:
        return 'Изменение по работе';
    }
  }

  Future<void> _enqueueCommand({
    required String kind,
    required String localId,
    required WorkAction action,
    required String commandKey,
    required int revision,
    String? assigneeId,
    String? dueAt,
    String? comment,
    String? dependsOn,
  }) async {
    final sync = _sync;
    if (sync == null) return;
    final targetEntity = switch (kind) {
      'maintenance' => SyncEntity.maintenance,
      'station' => SyncEntity.stations,
      _ => SyncEntity.requests,
    };
    await sync.publishUpsertPayload(
      entity: SyncEntity.workCommands,
      localPk: commandKey,
      dependsOn: dependsOn,
      payload: {
        'command_key': commandKey,
        'target_entity': targetEntity,
        'target_local_id': localId,
        'kind': kind,
        'action': action.name,
        'base_revision': revision,
        'assignee_id': assigneeId,
        'due_at': dueAt,
        'comment': comment,
        'correlation_id': correlationId(
          entity: kind,
          localId: localId,
          at: _clock(),
        ),
      },
    );
  }

  Future<void> _publishEntity(String entity, String localPk) async {
    final sync = _sync;
    if (sync == null) return;
    await sync.publishUpsert(entity: entity, localPk: localPk);
  }
}
