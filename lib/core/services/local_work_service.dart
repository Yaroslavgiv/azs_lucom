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
    final now = _clock().toIso8601String();
    final id = await _db.db.insert('requests', {
      'station_number': stationNumber,
      'type': 'НЗ',
      'request_type': requestType,
      'description': description,
      'date_created': now.substring(0, 10),
      'status': 'open',
      'uuid': newUuid(),
      'category': category,
      'author_id': actor.userId,
      'critical': critical ? 1 : 0,
      'revision': 0,
      'workflow_status': 'created',
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
      nextValue: 'created',
    );
    return id;
  }

  Future<WorkCommandResult> applyRequest({
    required AccessSubject actor,
    required int requestId,
    required WorkAction action,
    String? comment,
    String? assigneeId,
    String? dueAt,
    bool checklistComplete = true,
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
      assigneeId: action == WorkAction.assign || action == WorkAction.reassign
          ? assigneeId
          : currentAssignee,
      assignedToActor: currentAssignee == actor.userId,
      checklistComplete: checklistComplete,
    );
    if (!result.succeeded) {
      throw WorkDenied(result.denial ?? 'Переход недоступен');
    }
    if (result.idempotentReplay) return result;

    final next = result.nextStatus!;
    final nextAssignee =
        action == WorkAction.assign || action == WorkAction.reassign
        ? assigneeId
        : currentAssignee;
    await _db.db.update(
      'requests',
      {
        'workflow_status': next,
        'status': legacyRequestStatus(next),
        'assignee_id': nextAssignee,
        'due_at': dueAt ?? row['due_at'],
        'revision': revision + 1,
        'last_command_key': commandKey,
        'close_comment': action == WorkAction.returnForRework
            ? comment
            : row['close_comment'],
        'close_date': next == 'accepted' || next == 'cancelled'
            ? _clock().toIso8601String()
            : row['close_date'],
        'result_text': action == WorkAction.submit
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
      assigneeId: nextAssignee,
      actor: actor,
    );
    await _enqueueCommand(
      kind: 'request',
      localId: '$requestId',
      action: action,
      commandKey: commandKey,
      revision: revision,
      assigneeId: nextAssignee,
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
      'workflow_status': 'planned',
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
    String? assigneeId,
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
    final currentAssignee = row['assignee_id'] as String?;
    final checklistComplete = action == WorkAction.submit
        ? await _checklistComplete(localId)
        : true;
    final result = applyWorkCommand(
      actor: actor,
      station: station,
      kind: WorkKind.maintenance,
      currentStatus: (row['workflow_status'] as String?) ?? 'planned',
      action: action,
      commandKey: commandKey,
      lastCommandKey: row['last_command_key'] as String?,
      comment: comment,
      assigneeId: action == WorkAction.assign || action == WorkAction.reassign
          ? assigneeId
          : currentAssignee,
      assignedToActor: currentAssignee == actor.userId,
      checklistComplete: checklistComplete,
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
        'assignee_id':
            action == WorkAction.assign || action == WorkAction.reassign
            ? assigneeId
            : currentAssignee,
        'due_at': dueAt ?? row['due_at'],
        'revision': revision + 1,
        'last_command_key': commandKey,
        'accepted_at': next == 'accepted'
            ? _clock().toIso8601String()
            : row['accepted_at'],
        'date_done': next == 'accepted'
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
      assigneeId: assigneeId ?? currentAssignee,
      actor: actor,
    );
    await _enqueueCommand(
      kind: 'maintenance',
      localId: localId,
      action: action,
      commandKey: commandKey,
      revision: revision,
      assigneeId: assigneeId ?? currentAssignee,
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
    return OrgStation(
      number: number,
      managementId: row['management_id'] as String?,
      departmentId: row['department_id'] as String?,
      crewId: row['crew_id'] as String?,
      region: row['region'] as String?,
    );
  }

  Future<bool> _checklistComplete(String maintenanceKey) async {
    final template = await checklistTemplateItems();
    if (template.isEmpty) return true;
    final results = await _db.db.query(
      'checklist_results',
      where: 'maintenance_key = ?',
      whereArgs: [maintenanceKey],
    );
    final byItem = {
      for (final row in results)
        row['item_id'] as String: row['result'] as String?,
    };
    return checklistReadyForSubmit(
      template.map(
        (item) => ChecklistItemDraft(
          id: item['id'] as String? ?? '',
          required: item['required'] == true,
          result: byItem[item['id']],
        ),
      ),
    );
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
