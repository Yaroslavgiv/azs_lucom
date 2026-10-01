import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/navigation/app_page_route.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/glass_card.dart';
import '../requests/request_work_page.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).value?.id;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Уведомления')),
        body: userId == null
            ? const Center(child: Text('Нет активного пользователя'))
            : FutureBuilder<List<Map<String, Object?>>>(
                future: ref
                    .read(notificationRepositoryProvider.future)
                    .then((repo) => repo.listFor(userId)),
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const [];
                  if (rows.isEmpty) {
                    return const Center(
                      child: Text(
                        'Нет уведомлений',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            onTap: () async {
                              final repo = await ref.read(
                                notificationRepositoryProvider.future,
                              );
                              await repo.markRead(row['id'] as String);
                              final entityId =
                                  row['entity_id'] as String? ?? '';
                              final requestId = int.tryParse(entityId);
                              if (requestId != null && context.mounted) {
                                await Navigator.of(context).push(
                                  AppPageRoute(
                                    page: RequestWorkPage(requestId: requestId),
                                  ),
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${row['title']}'),
                                Text(
                                  '${row['body']}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
