import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/auth/pending_approval_page.dart';
import 'features/manager/manager_web_shell.dart';
import 'features/shell/main_shell.dart';
import 'shared/widgets/app_background.dart';

class AzsApp extends ConsumerWidget {
  const AzsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'АЗС — заявки и ТО',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: auth.when(
        data: (user) {
          if (user == null) return const LoginPage();
          return const _AuthenticatedHome();
        },
        loading: () => const _LoadingScreen(message: 'Проверка входа…'),
        error: (error, _) =>
            _ErrorScreen(message: 'Ошибка авторизации: $error'),
      ),
    );
  }
}

class _AuthenticatedHome extends ConsumerWidget {
  const _AuthenticatedHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const _LoadingScreen(message: 'Загрузка профиля…'),
      error: (error, _) => _ErrorScreen(message: 'Ошибка профиля: $error'),
      data: (profile) {
        if (profile == null) {
          return const _LoadingScreen(message: 'Подготовка профиля…');
        }
        if (!profile.canAccessApp) {
          return PendingApprovalPage(profile: profile);
        }

        final init = ref.watch(appInitProvider);
        return init.when(
          data: (_) {
            // Web + руководитель/админ → панель из концепта КП.
            if (kIsWeb && profile.canManageUsers) {
              return const ManagerWebShell();
            }
            return const MainShell();
          },
          loading: () => const _LoadingScreen(message: 'Загрузка…'),
          error: (error, _) =>
              _ErrorScreen(message: 'Ошибка запуска: $error'),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}
