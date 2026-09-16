import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/domain/user_role.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class WebUsersPage extends ConsumerWidget {
  const WebUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProfileProvider).value;
    if (me?.role != UserRole.admin) {
      return const Center(
        child: Text('Управление пользователями доступно администратору'),
      );
    }
    return FutureBuilder(
      future: ref
          .read(userProfileRepositoryProvider.future)
          .then((repo) => repo.listAll()),
      builder: (context, snapshot) {
        final users = snapshot.data ?? <UserProfile>[];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppPrimaryButton(
                label: 'Новый пользователь',
                expand: false,
                onPressed: () => _create(context, ref),
              ),
            ),
            const SizedBox(height: 12),
            for (final user in users)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Text(
                    '${user.shortName}\n${user.email} · ${user.role.label} · ${user.regions.join(', ')}',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();
    var role = UserRole.specialist;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать пользователя'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: password,
              decoration: const InputDecoration(labelText: 'Пароль'),
              obscureText: true,
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            DropdownButton<UserRole>(
              value: role,
              items: [
                for (final value in UserRole.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) => role = value ?? role,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('createAppUser').call({
        'email': email.text.trim(),
        'password': password.text,
        'displayName': name.text.trim(),
        'role': role.wireValue,
        'regions': [regionSpb, regionNovgorod],
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Пользователь создан')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не удалось создать: $error')));
      }
    }
  }
}
