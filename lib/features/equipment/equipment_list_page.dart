import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/navigation/app_page_route.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/glass_card.dart';
import 'equipment_edit_page.dart';

class EquipmentListPage extends ConsumerWidget {
  const EquipmentListPage({super.key, required this.stationNumber});

  final String stationNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('Оборудование $stationNumber')),
        body: FutureBuilder(
          future: ref
              .read(equipmentRepositoryProvider.future)
              .then((repo) => repo.listForStation(stationNumber)),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'Нет оборудования',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () => Navigator.of(
                        context,
                      ).push(AppPageRoute(page: EquipmentEditPage(item: item))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.category),
                          Text(item.description),
                          Text(
                            'Модель: ${item.model.isEmpty ? 'не указана' : item.model}'
                            ' · ${item.quantity} шт.',
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
