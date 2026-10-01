enum AppRole { specialist, manager, departmentHead, managementHead, admin }

AppRole? appRoleFromCode(String? code) {
  switch (code) {
    case 'specialist':
      return AppRole.specialist;
    case 'manager':
      return AppRole.manager;
    case 'department_head':
      return AppRole.departmentHead;
    case 'management_head':
      return AppRole.managementHead;
    case 'admin':
      return AppRole.admin;
    default:
      return null;
  }
}

String appRoleCode(AppRole role) {
  switch (role) {
    case AppRole.specialist:
      return 'specialist';
    case AppRole.manager:
      return 'manager';
    case AppRole.departmentHead:
      return 'department_head';
    case AppRole.managementHead:
      return 'management_head';
    case AppRole.admin:
      return 'admin';
  }
}

String appRoleLabel(AppRole role) {
  switch (role) {
    case AppRole.specialist:
      return 'Специалист';
    case AppRole.manager:
      return 'Руководитель';
    case AppRole.departmentHead:
      return 'Начальник отдела';
    case AppRole.managementHead:
      return 'Начальник управления';
    case AppRole.admin:
      return 'Администратор';
  }
}

class AccessSubject {
  const AccessSubject({
    required this.userId,
    required this.role,
    this.managementId,
    this.departmentId,
    this.crewId,
    this.active = true,
  });

  final String userId;
  final AppRole role;
  final String? managementId;
  final String? departmentId;
  final String? crewId;
  final bool active;

  bool get isLeader =>
      role == AppRole.manager ||
      role == AppRole.departmentHead ||
      role == AppRole.managementHead;
}

class OrgStation {
  const OrgStation({
    required this.number,
    this.managementId,
    this.departmentId,
    this.crewId,
    this.region,
  });

  final String number;
  final String? managementId;
  final String? departmentId;
  final String? crewId;
  final String? region;
}

bool canReadStation(
  AccessSubject actor,
  OrgStation station, {
  bool assignedToActor = false,
}) {
  if (!actor.active) return false;
  switch (actor.role) {
    case AppRole.admin:
      return true;
    case AppRole.managementHead:
      return _same(actor.managementId, station.managementId);
    case AppRole.departmentHead:
      return _same(actor.departmentId, station.departmentId);
    case AppRole.manager:
      if (actor.departmentId != null && actor.departmentId!.isNotEmpty) {
        return _same(actor.departmentId, station.departmentId);
      }
      return _same(actor.managementId, station.managementId);
    case AppRole.specialist:
      if (assignedToActor) return true;
      return _same(actor.crewId, station.crewId);
  }
}

bool canManageDirectories(AccessSubject actor) =>
    actor.active && actor.role == AppRole.admin;

bool canAcceptWork(AccessSubject actor) => actor.active && actor.isLeader;

bool canExecuteWork(AccessSubject actor, {required String? assigneeId}) =>
    actor.active &&
    actor.role == AppRole.specialist &&
    assigneeId != null &&
    assigneeId == actor.userId;

bool canCreateStation(AccessSubject actor) =>
    actor.active && actor.role != AppRole.specialist;

bool canChangeCrew(AccessSubject actor, OrgStation station) =>
    actor.active && actor.isLeader && canReadStation(actor, station);

/// Перевод между отделами и управлениями блокируется, пока заказчик
/// не согласует судьбу открытых заявок и ТО.
bool canReassignCrew({
  required AccessSubject actor,
  required OrgStation station,
  required String? targetManagementId,
  required String? targetDepartmentId,
  required String? targetCrewId,
}) {
  if (!canChangeCrew(actor, station)) return false;
  if (targetCrewId == null || targetCrewId.isEmpty) return false;
  if (!_same(station.managementId, targetManagementId)) return false;
  if (!_same(station.departmentId, targetDepartmentId)) return false;
  return true;
}

bool canReadAudit(AccessSubject actor, {String? eventManagementId}) {
  if (!actor.active) return false;
  if (actor.role == AppRole.admin) return true;
  if (!actor.isLeader) return false;
  return _same(actor.managementId, eventManagementId);
}

bool _same(String? left, String? right) =>
    left != null && left.isNotEmpty && left == right;
