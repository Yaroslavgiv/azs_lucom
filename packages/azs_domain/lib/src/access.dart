enum AppRole { specialist, manager, admin }

enum ManagerScope { department, management }

class DecodedRole {
  const DecodedRole({required this.role, this.scope});

  final AppRole role;
  final ManagerScope? scope;
}

/// `department_head` и `management_head` остаются только как старые коды профиля.
DecodedRole? decodeRole(
  String? code, {
  String? scopeCode,
  String? departmentId,
}) {
  switch (code) {
    case 'specialist':
      return const DecodedRole(role: AppRole.specialist);
    case 'admin':
      return const DecodedRole(role: AppRole.admin);
    case 'department_head':
      return const DecodedRole(
        role: AppRole.manager,
        scope: ManagerScope.department,
      );
    case 'management_head':
      return const DecodedRole(
        role: AppRole.manager,
        scope: ManagerScope.management,
      );
    case 'manager':
      return DecodedRole(
        role: AppRole.manager,
        scope:
            managerScopeFromCode(scopeCode) ??
            ((departmentId != null && departmentId.isNotEmpty)
                ? ManagerScope.department
                : ManagerScope.management),
      );
    default:
      return null;
  }
}

AppRole? appRoleFromCode(String? code) => decodeRole(code)?.role;

ManagerScope? managerScopeFromCode(String? code) {
  switch (code) {
    case 'department':
      return ManagerScope.department;
    case 'management':
      return ManagerScope.management;
    default:
      return null;
  }
}

String? managerScopeCode(ManagerScope? scope) {
  switch (scope) {
    case ManagerScope.department:
      return 'department';
    case ManagerScope.management:
      return 'management';
    case null:
      return null;
  }
}

String appRoleCode(AppRole role) {
  switch (role) {
    case AppRole.specialist:
      return 'specialist';
    case AppRole.manager:
      return 'manager';
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
    case AppRole.admin:
      return 'Администратор';
  }
}

String managerScopeLabel(ManagerScope scope) {
  switch (scope) {
    case ManagerScope.department:
      return 'отдел';
    case ManagerScope.management:
      return 'управление';
  }
}

class AccessSubject {
  const AccessSubject({
    required this.userId,
    required this.role,
    this.scope,
    this.managementId,
    this.departmentId,
    this.crewId,
    this.active = true,
  });

  final String userId;
  final AppRole role;
  final ManagerScope? scope;
  final String? managementId;
  final String? departmentId;
  final String? crewId;
  final bool active;

  bool get isLeader => role == AppRole.manager;

  ManagerScope? get effectiveScope {
    if (role != AppRole.manager) return null;
    if (scope != null) return scope;
    if (departmentId != null && departmentId!.isNotEmpty) {
      return ManagerScope.department;
    }
    return ManagerScope.management;
  }
}

AccessSubject subjectFromCodes({
  required String userId,
  String? roleCode,
  String? scopeCode,
  String? managementId,
  String? departmentId,
  String? crewId,
  bool active = true,
}) {
  final decoded = decodeRole(
    roleCode,
    scopeCode: scopeCode,
    departmentId: departmentId,
  );
  return AccessSubject(
    userId: userId,
    role: decoded?.role ?? AppRole.specialist,
    scope: decoded?.scope,
    managementId: managementId,
    departmentId: departmentId,
    crewId: crewId,
    active: active,
  );
}

class OrgStation {
  const OrgStation({
    required this.number,
    this.managementId,
    this.departmentId,
    this.crewId,
    this.region,
    this.specialistId,
  });

  final String number;
  final String? managementId;
  final String? departmentId;
  final String? crewId;
  final String? region;
  final String? specialistId;
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
    case AppRole.manager:
      if (actor.effectiveScope == ManagerScope.department) {
        return _same(actor.departmentId, station.departmentId);
      }
      return _same(actor.managementId, station.managementId);
    case AppRole.specialist:
      if (assignedToActor) return true;
      final responsible = station.specialistId;
      if (responsible != null && responsible.isNotEmpty) {
        return responsible == actor.userId;
      }
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

bool canAssignStationSpecialist(AccessSubject actor, OrgStation station) {
  if (!actor.active || !canReadStation(actor, station)) return false;
  return actor.role == AppRole.admin || actor.isLeader;
}

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
