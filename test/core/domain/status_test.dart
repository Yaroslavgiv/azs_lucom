import 'package:azs_app/core/domain/maintenance_lifecycle.dart';
import 'package:azs_app/core/domain/request_status.dart';
import 'package:azs_app/core/domain/time_period.dart';
import 'package:azs_app/core/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy request statuses stay active or closed', () {
    expect(RequestStatus.isActive('open'), isTrue);
    expect(RequestStatus.isActive('new'), isTrue);
    expect(RequestStatus.isClosed('closed'), isTrue);
    expect(RequestStatus.isClosed('done'), isTrue);
    expect(RequestStatus.normalize('open'), RequestStatus.created);
  });

  test('legacy maintenance done is treated as accepted', () {
    expect(MaintenanceLifecycle.isAccepted('done'), isTrue);
    expect(MaintenanceLifecycle.isAccepted('accepted'), isTrue);
    expect(
      MaintenanceLifecycle.normalize('pending'),
      MaintenanceLifecycle.planned,
    );
  });

  test('manager and admin can accept maintenance', () {
    expect(UserRole.specialist.canAcceptMaintenance, isFalse);
    expect(UserRole.manager.canAcceptMaintenance, isTrue);
    expect(UserRole.admin.canManageUsers, isTrue);
  });

  test('due date before today is overdue', () {
    expect(isDueDateOverdue('2020-01-01', DateTime(2026, 9, 16)), isTrue);
    expect(isDueDateOverdue('2026-09-16', DateTime(2026, 9, 16)), isFalse);
  });
}
