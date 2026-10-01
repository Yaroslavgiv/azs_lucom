import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';

class ManagerOverviewPage extends ConsumerWidget {
  const ManagerOverviewPage({super.key});

  static const _monthNames = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(managerOverviewProvider);
    final now = DateTime.now();
    final monthLabel = '${_monthNames[now.month - 1]} ${now.year}';

    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Не удалось загрузить обзор: $error',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: (stats) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(
              'Обслуживание сети / $monthLabel',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Сводка по станциям, ТО и открытым заявкам',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final cards = [
                  _KpiCard(
                    label: 'ТО принято',
                    value: '${stats.maintenanceDone} / ${stats.stationCount}',
                    color: AppColors.success,
                  ),
                  _KpiCard(
                    label: 'Осталось ТО',
                    value: '${stats.maintenancePending}',
                    color: AppColors.warning,
                  ),
                  _KpiCard(
                    label: 'Открытые заявки',
                    value: '${stats.openRequests}',
                    color: AppColors.info,
                  ),
                  _KpiCard(
                    label: 'Требуют внимания',
                    value: '${stats.attentionItems.length}',
                    color: AppColors.error,
                  ),
                ];
                if (wide) {
                  return Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        Expanded(child: cards[i]),
                        if (i != cards.length - 1) const SizedBox(width: 12),
                      ],
                    ],
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final card in cards)
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: card,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Объекты, требующие внимания',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (stats.attentionItems.isEmpty)
              const GlassCard(
                child: Text(
                  'Критичных объектов нет',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              GlassCard(
                child: Column(
                  children: [
                    for (final item in stats.attentionItems) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                        title: Text('АЗС ${item.stationNumber}'),
                        subtitle: Text(
                          [
                            if (item.stationName.isNotEmpty) item.stationName,
                            item.reason,
                          ].join(' · '),
                        ),
                      ),
                      if (item != stats.attentionItems.last)
                        const Divider(height: 1, color: AppColors.border),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
