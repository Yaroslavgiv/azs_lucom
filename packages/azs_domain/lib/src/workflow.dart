import 'access.dart';

enum WorkKind { request, maintenance }

enum WorkAction {
  assign,
  reassign,
  start,
  submit,
  accept,
  returnForRework,
  cancel,
  resume,
  complete,
}

enum RequestWorkflowStatus {
  created,
  unassigned,
  assigned,
  inProgress,
  onReview,
  returned,
  accepted,
  closed,
  cancelled,
}

enum MaintenanceWorkflowStatus {
  notDone,
  planned,
  assigned,
  inProgress,
  onReview,
  returned,
  accepted,
  done,
  overdue,
}

String requestWorkflowCode(RequestWorkflowStatus status) {
  switch (status) {
    case RequestWorkflowStatus.created:
      return 'created';
    case RequestWorkflowStatus.unassigned:
      return 'unassigned';
    case RequestWorkflowStatus.assigned:
      return 'assigned';
    case RequestWorkflowStatus.inProgress:
      return 'in_progress';
    case RequestWorkflowStatus.onReview:
      return 'on_review';
    case RequestWorkflowStatus.returned:
      return 'returned';
    case RequestWorkflowStatus.accepted:
      return 'accepted';
    case RequestWorkflowStatus.closed:
      return 'closed';
    case RequestWorkflowStatus.cancelled:
      return 'cancelled';
  }
}

RequestWorkflowStatus? requestWorkflowFromCode(String? code) {
  switch (code) {
    case 'created':
      return RequestWorkflowStatus.created;
    case 'unassigned':
      return RequestWorkflowStatus.unassigned;
    case 'assigned':
      return RequestWorkflowStatus.assigned;
    case 'in_progress':
      return RequestWorkflowStatus.inProgress;
    case 'on_review':
      return RequestWorkflowStatus.onReview;
    case 'returned':
      return RequestWorkflowStatus.returned;
    case 'accepted':
      return RequestWorkflowStatus.accepted;
    case 'closed':
      return RequestWorkflowStatus.closed;
    case 'cancelled':
      return RequestWorkflowStatus.cancelled;
    default:
      return null;
  }
}

String requestWorkflowLabel(String code) {
  switch (code) {
    case 'created':
      return 'Новая';
    case 'unassigned':
      return 'Без исполнителя';
    case 'assigned':
      return 'Назначена';
    case 'in_progress':
      return 'В работе';
    case 'on_review':
      return 'На проверке';
    case 'returned':
      return 'Возвращена';
    case 'accepted':
      return 'Принята';
    case 'closed':
      return 'Закрыта';
    case 'cancelled':
      return 'Отменена';
    default:
      return code;
  }
}

String maintenanceWorkflowCode(MaintenanceWorkflowStatus status) {
  switch (status) {
    case MaintenanceWorkflowStatus.notDone:
      return 'not_done';
    case MaintenanceWorkflowStatus.planned:
      return 'planned';
    case MaintenanceWorkflowStatus.assigned:
      return 'assigned';
    case MaintenanceWorkflowStatus.inProgress:
      return 'in_progress';
    case MaintenanceWorkflowStatus.onReview:
      return 'on_review';
    case MaintenanceWorkflowStatus.returned:
      return 'returned';
    case MaintenanceWorkflowStatus.accepted:
      return 'accepted';
    case MaintenanceWorkflowStatus.done:
      return 'done';
    case MaintenanceWorkflowStatus.overdue:
      return 'overdue';
  }
}

MaintenanceWorkflowStatus? maintenanceWorkflowFromCode(String? code) {
  switch (code) {
    case 'not_done':
      return MaintenanceWorkflowStatus.notDone;
    case 'planned':
      return MaintenanceWorkflowStatus.planned;
    case 'assigned':
      return MaintenanceWorkflowStatus.assigned;
    case 'in_progress':
      return MaintenanceWorkflowStatus.inProgress;
    case 'on_review':
      return MaintenanceWorkflowStatus.onReview;
    case 'returned':
      return MaintenanceWorkflowStatus.returned;
    case 'accepted':
      return MaintenanceWorkflowStatus.accepted;
    case 'done':
      return MaintenanceWorkflowStatus.done;
    case 'overdue':
      return MaintenanceWorkflowStatus.overdue;
    default:
      return null;
  }
}

String maintenanceWorkflowLabel(String code) {
  switch (code) {
    case 'not_done':
    case 'planned':
      return 'Не выполнено';
    case 'assigned':
      return 'Назначено';
    case 'in_progress':
      return 'В работе';
    case 'on_review':
      return 'На проверке';
    case 'returned':
      return 'Возвращено';
    case 'accepted':
    case 'done':
      return 'Выполнено';
    case 'overdue':
      return 'Просрочено';
    default:
      return code;
  }
}

String legacyRequestStatus(String workflowCode) {
  if (workflowCode == 'accepted' ||
      workflowCode == 'closed' ||
      workflowCode == 'cancelled') {
    return 'closed';
  }
  return 'open';
}

String legacyMaintenanceStatus(String workflowCode) {
  if (workflowCode == 'accepted' || workflowCode == 'done') return 'done';
  return 'pending';
}

class WorkCommandResult {
  const WorkCommandResult._({
    required this.applied,
    required this.idempotentReplay,
    this.nextStatus,
    this.denial,
  });

  const WorkCommandResult.applied(String status)
    : this._(applied: true, idempotentReplay: false, nextStatus: status);

  const WorkCommandResult.replay(String status)
    : this._(applied: false, idempotentReplay: true, nextStatus: status);

  const WorkCommandResult.denied(String reason)
    : this._(applied: false, idempotentReplay: false, denial: reason);

  final bool applied;
  final bool idempotentReplay;
  final String? nextStatus;
  final String? denial;

  bool get succeeded => applied || idempotentReplay;
}

const _leaderActions = {
  WorkAction.accept,
  WorkAction.returnForRework,
  WorkAction.cancel,
};

const _specialistActions = {
  WorkAction.start,
  WorkAction.submit,
  WorkAction.resume,
  WorkAction.complete,
};

WorkCommandResult applyWorkCommand({
  required AccessSubject actor,
  required OrgStation station,
  required WorkKind kind,
  required String currentStatus,
  required WorkAction action,
  required String commandKey,
  String? lastCommandKey,
  String? comment,
  String? assigneeId,
  bool assignedToActor = false,
  bool requiresReview = false,
}) {
  if (!canReadStation(actor, station, assignedToActor: assignedToActor)) {
    return const WorkCommandResult.denied('Нет доступа к объекту');
  }

  if (lastCommandKey != null && lastCommandKey == commandKey) {
    return WorkCommandResult.replay(currentStatus);
  }

  if (action == WorkAction.assign || action == WorkAction.reassign) {
    return const WorkCommandResult.denied('Назначение вручную недоступно');
  }
  if (kind == WorkKind.maintenance && currentStatus == 'overdue') {
    return const WorkCommandResult.denied('Месяц закрыт как просроченный');
  }

  final next = _nextStatus(kind: kind, current: currentStatus, action: action);
  if (next == null) {
    if (_isSameOutcome(kind: kind, current: currentStatus, action: action)) {
      return WorkCommandResult.replay(currentStatus);
    }
    return const WorkCommandResult.denied('Переход недоступен');
  }

  if (_leaderActions.contains(action) && !canAcceptWork(actor)) {
    return const WorkCommandResult.denied(
      'Операция доступна только руководителю',
    );
  }
  if (_specialistActions.contains(action) &&
      !canExecuteWork(actor, assigneeId: assigneeId)) {
    return const WorkCommandResult.denied(
      'Исполнять может только назначенный специалист',
    );
  }
  if (action == WorkAction.returnForRework &&
      (comment == null || comment.trim().isEmpty)) {
    return const WorkCommandResult.denied('Возврат требует комментарий');
  }
  if (action == WorkAction.complete &&
      kind == WorkKind.request &&
      requiresReview) {
    return const WorkCommandResult.denied(
      'Заявка требует проверки руководителя',
    );
  }
  if (action == WorkAction.cancel && kind != WorkKind.request) {
    return const WorkCommandResult.denied('Отмена доступна только для заявки');
  }

  return WorkCommandResult.applied(next);
}

String? _nextStatus({
  required WorkKind kind,
  required String current,
  required WorkAction action,
}) {
  if (kind == WorkKind.request) {
    return _requestTransitions[current]?[action];
  }
  if (action != WorkAction.complete) return null;
  const open = {
    'not_done',
    'planned',
    'assigned',
    'in_progress',
    'on_review',
    'returned',
  };
  if (open.contains(current)) return 'done';
  return null;
}

bool _isSameOutcome({
  required WorkKind kind,
  required String current,
  required WorkAction action,
}) {
  if (action == WorkAction.accept && current == 'accepted') return true;
  if (action == WorkAction.complete &&
      (current == 'done' || current == 'accepted' || current == 'closed')) {
    return true;
  }
  if (action == WorkAction.submit && current == 'on_review') return true;
  if (action == WorkAction.start && current == 'in_progress') return true;
  return false;
}

const _requestTransitions = <String, Map<WorkAction, String>>{
  'unassigned': {WorkAction.cancel: 'cancelled'},
  'created': {
    WorkAction.start: 'in_progress',
    WorkAction.complete: 'closed',
    WorkAction.cancel: 'cancelled',
  },
  'assigned': {WorkAction.start: 'in_progress', WorkAction.complete: 'closed'},
  'in_progress': {
    WorkAction.submit: 'on_review',
    WorkAction.complete: 'closed',
  },
  'on_review': {
    WorkAction.accept: 'accepted',
    WorkAction.returnForRework: 'returned',
  },
  'returned': {
    WorkAction.resume: 'in_progress',
    WorkAction.submit: 'on_review',
    WorkAction.complete: 'closed',
  },
};

bool isOverdue({
  required DateTime? dueAt,
  required String workflowStatus,
  required DateTime now,
}) {
  if (dueAt == null) return false;
  const closed = {'accepted', 'cancelled', 'closed', 'done'};
  if (closed.contains(workflowStatus)) return false;
  return !now.isBefore(dueAt);
}

/// Граница срока в часовом поясе Europe/Moscow (UTC+3, без перехода на летнее время).
DateTime moscowDeadline(DateTime dueDate) {
  final date = DateTime.utc(
    dueDate.year,
    dueDate.month,
    dueDate.day,
    20,
    59,
    59,
  );
  return date;
}
