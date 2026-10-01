import 'package:azs_app/core/constants.dart';
import 'package:azs_app/core/models/app_role.dart';
import 'package:azs_app/core/models/user_profile.dart';
import 'package:azs_app/core/repositories/user_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('approved manager can manage users', () {
    const profile = UserProfile(
      id: '1',
      email: 'dom-tuap@yandex.ru',
      displayName: 'Руководитель',
      role: AppRole.manager,
      status: AccountStatus.approved,
    );

    expect(profile.canAccessApp, isTrue);
    expect(profile.canManageUsers, isTrue);
  });

  test('pending specialist cannot access app', () {
    const profile = UserProfile(
      id: '2',
      email: 'spec@example.com',
      displayName: 'Специалист',
      role: AppRole.specialist,
      status: AccountStatus.pending,
    );

    expect(profile.canAccessApp, isFalse);
    expect(profile.canManageUsers, isFalse);
  });

  test('offline fallback: manager bootstrap is approved', () {
    final profile = UserProfileRepository.offlineFallbackProfile(
      userId: 'uid-1',
      email: managerBootstrapEmail,
    );

    expect(profile.role, AppRole.manager);
    expect(profile.status, AccountStatus.approved);
    expect(profile.canAccessApp, isTrue);
  });

  test('offline fallback: specialist stays pending', () {
    final profile = UserProfileRepository.offlineFallbackProfile(
      userId: 'uid-2',
      email: 'worker@example.com',
      displayName: 'Иван',
    );

    expect(profile.role, AppRole.specialist);
    expect(profile.status, AccountStatus.pending);
    expect(profile.displayName, 'Иван');
    expect(profile.canAccessApp, isFalse);
  });
}
