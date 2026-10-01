import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_role.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class PendingApprovalPage extends ConsumerWidget {
  const PendingApprovalPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRejected = profile.status == AccountStatus.rejected;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        isRejected
                            ? Icons.block
                            : Icons.hourglass_top_rounded,
                        size: 40,
                        color: isRejected
                            ? AppColors.error
                            : AppColors.warning,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isRejected
                            ? 'Доступ отклонён'
                            : 'Заявка на рассмотрении',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isRejected
                            ? 'Руководитель отклонил регистрацию для '
                                  '${profile.email}. Обратитесь к руководителю.'
                            : 'Аккаунт ${profile.email} создан. Руководитель '
                                  'должен одобрить заявку в панели управления.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      AppSecondaryButton(
                        label: 'Выйти',
                        icon: Icons.logout,
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
