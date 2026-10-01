import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_role.dart';
import '../../core/models/registration_request.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/date_format.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class ManagerAdminPage extends ConsumerStatefulWidget {
  const ManagerAdminPage({super.key});

  @override
  ConsumerState<ManagerAdminPage> createState() => _ManagerAdminPageState();
}

class _ManagerAdminPageState extends ConsumerState<ManagerAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _busy = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _approve(
    RegistrationRequest request, {
    required AppRole role,
  }) async {
    final reviewer = ref.read(currentUserProfileProvider).valueOrNull;
    if (reviewer == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .approveRegistration(
            userId: request.id,
            role: role,
            reviewerId: reviewer.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${request.displayName}: одобрен как ${role.labelRu}',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось одобрить заявку')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(RegistrationRequest request) async {
    final reviewer = ref.read(currentUserProfileProvider).valueOrNull;
    if (reviewer == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .rejectRegistration(
            userId: request.id,
            reviewerId: reviewer.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${request.displayName}: заявка отклонена')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отклонить заявку')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeRole(UserProfile user, AppRole role) async {
    final reviewer = ref.read(currentUserProfileProvider).valueOrNull;
    if (reviewer == null) return;
    if (user.id == reviewer.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя изменить собственную роль здесь')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .updateUserRole(
            userId: user.id,
            role: role,
            reviewerId: reviewer.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.email}: роль ${role.labelRu}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось изменить роль')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<AppRole?> _pickRole({
    required String title,
    AppRole initial = AppRole.specialist,
  }) async {
    var selected = initial;
    return showDialog<AppRole>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(title),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final role in [
                    AppRole.specialist,
                    AppRole.admin,
                    AppRole.manager,
                  ])
                    ListTile(
                      title: Text(role.labelRu),
                      leading: Icon(
                        selected == role
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.accent,
                      ),
                      onTap: () => setLocal(() => selected = role),
                    ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Подтвердить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final pending = ref.watch(pendingRegistrationRequestsProvider);
    final users = ref.watch(managedUsersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Пользователи и доступ',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile == null
                            ? 'Управление доступом'
                            : '${profile.displayName} · ${profile.role.labelRu}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Выйти',
                  onPressed: () =>
                      ref.read(authRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
          ),
        ),
        TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          tabs: [
            Tab(
              text: pending.maybeWhen(
                data: (items) => 'Заявки (${items.length})',
                orElse: () => 'Заявки',
              ),
            ),
            const Tab(text: 'Пользователи'),
          ],
        ),
        if (_busy) const LinearProgressIndicator(color: AppColors.accent),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PendingRequestsTab(
                asyncRequests: pending,
                onApprove: (request) async {
                  final role = await _pickRole(
                    title: 'Назначить роль при одобрении',
                  );
                  if (role == null) return;
                  await _approve(request, role: role);
                },
                onReject: _reject,
              ),
              _UsersTab(
                asyncUsers: users,
                onChangeRole: (user) async {
                  final role = await _pickRole(
                    title: 'Изменить роль',
                    initial: user.role,
                  );
                  if (role == null) return;
                  await _changeRole(user, role);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingRequestsTab extends StatelessWidget {
  const _PendingRequestsTab({
    required this.asyncRequests,
    required this.onApprove,
    required this.onReject,
  });

  final AsyncValue<List<RegistrationRequest>> asyncRequests;
  final Future<void> Function(RegistrationRequest request) onApprove;
  final Future<void> Function(RegistrationRequest request) onReject;

  @override
  Widget build(BuildContext context) {
    return asyncRequests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Не удалось загрузить заявки: $error',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'Новых заявок нет',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final request = items[index];
            return GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.email,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.createdAt == null
                        ? 'Дата неизвестна'
                        : 'Заявка: ${formatRuDateTime(request.createdAt!)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'Одобрить',
                          icon: Icons.check,
                          onPressed: () => onApprove(request),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'Отклонить',
                          icon: Icons.close,
                          onPressed: () => onReject(request),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.asyncUsers, required this.onChangeRole});

  final AsyncValue<List<UserProfile>> asyncUsers;
  final Future<void> Function(UserProfile user) onChangeRole;

  @override
  Widget build(BuildContext context) {
    return asyncUsers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Не удалось загрузить пользователей: $error',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'Пользователей пока нет',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final user = items[index];
            return GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  user.displayName.isEmpty ? user.email : user.displayName,
                ),
                subtitle: Text(
                  '${user.email}\n${user.role.labelRu} · ${user.status.labelRu}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Изменить роль',
                  onPressed: () => onChangeRole(user),
                  icon: const Icon(Icons.manage_accounts_outlined),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
