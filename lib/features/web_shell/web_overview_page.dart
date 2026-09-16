import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import 'web_shell.dart';

class WebOverviewPage extends ConsumerWidget {
  const WebOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.watch(cloudDataServiceProvider).overview(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Обслуживание сети',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: KpiCard(
                    label: 'ТО принято',
                    value: '${data.acceptedMaintenance}',
                    accent: AppColors.success,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: KpiCard(
                    label: 'Осталось ТО',
                    value: '${data.remainingMaintenance}',
                    accent: AppColors.warning,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: KpiCard(
                    label: 'Открытые заявки',
                    value: '${data.openRequests}',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: KpiCard(
                    label: 'Просрочены',
                    value: '${data.overdueCount}',
                    accent: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Объекты, требующие внимания',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (data.attention.isEmpty)
              const GlassCard(child: Text('Нет объектов, требующих внимания'))
            else
              GlassCard(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('АЗС')),
                      DataColumn(label: Text('Причина')),
                      DataColumn(label: Text('Ответственный')),
                      DataColumn(label: Text('Срок')),
                    ],
                    rows: [
                      for (final item in data.attention)
                        DataRow(
                          cells: [
                            DataCell(Text(item.stationNumber)),
                            DataCell(Text(item.reason)),
                            DataCell(Text(item.assigneeName)),
                            DataCell(Text(item.dueDate)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
