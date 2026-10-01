import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';

class ManagerRequestsPage extends ConsumerWidget {
  const ManagerRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(managerOpenRequestsProvider);

    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Не удалось загрузить заявки: $error',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: (items) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(
              'Заявки на обслуживание',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Открытые заявки по сети (${items.length})',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const GlassCard(
                child: Text(
                  'Открытых заявок нет',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              GlassCard(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Заявка / АЗС')),
                      DataColumn(label: Text('Тип')),
                      DataColumn(label: Text('Описание')),
                      DataColumn(label: Text('Дата')),
                      DataColumn(label: Text('Статус')),
                    ],
                    rows: [
                      for (final item in items)
                        DataRow(
                          cells: [
                            DataCell(Text('№ ${item.id} / ${item.stationNumber}')),
                            DataCell(Text(item.requestType)),
                            DataCell(
                              SizedBox(
                                width: 280,
                                child: Text(
                                  item.description.isEmpty
                                      ? '—'
                                      : item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(item.dateCreated)),
                            DataCell(
                              Text(
                                item.status == 'open' ? 'Открыта' : item.status,
                                style: const TextStyle(color: AppColors.info),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Назначение исполнителя и срока — следующий этап панели '
              '(пока заявки доступны для контроля и экспорта).',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
