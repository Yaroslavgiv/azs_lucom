import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';

class ManagerStationsPage extends ConsumerStatefulWidget {
  const ManagerStationsPage({super.key});

  @override
  ConsumerState<ManagerStationsPage> createState() =>
      _ManagerStationsPageState();
}

class _ManagerStationsPageState extends ConsumerState<ManagerStationsPage> {
  String? _region;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(managerStationsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Не удалось загрузить станции: $error',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: (data) {
        final filtered = data.stations.where((station) {
          if (_region != null && station.region != _region) return false;
          if (_query.trim().isEmpty) return true;
          final q = _query.trim().toLowerCase();
          return station.number.toLowerCase().contains(q) ||
              station.name.toLowerCase().contains(q) ||
              station.address.toLowerCase().contains(q);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(
              'Станции сети',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Справочник АЗС и статус ТО за текущий месяц',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Все'),
                  selected: _region == null,
                  onSelected: (_) => setState(() => _region = null),
                ),
                ChoiceChip(
                  label: Text(regionLabelSpb),
                  selected: _region == regionSpb,
                  onSelected: (_) => setState(() => _region = regionSpb),
                ),
                ChoiceChip(
                  label: Text(regionLabelNovgorod),
                  selected: _region == regionNovgorod,
                  onSelected: (_) => setState(() => _region = regionNovgorod),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Поиск по номеру или адресу',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('АЗС')),
                    DataColumn(label: Text('Название')),
                    DataColumn(label: Text('Регион')),
                    DataColumn(label: Text('Адрес')),
                    DataColumn(label: Text('ТО')),
                  ],
                  rows: [
                    for (final station in filtered)
                      DataRow(
                        cells: [
                          DataCell(Text(station.number)),
                          DataCell(Text(station.name.isEmpty ? '—' : station.name)),
                          DataCell(
                            Text(
                              station.region == regionNovgorod
                                  ? regionLabelNovgorod
                                  : regionLabelSpb,
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 260,
                              child: Text(
                                station.address.isEmpty ? '—' : station.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              data.statuses[station.number]?.isDone == true
                                  ? 'Принято'
                                  : 'Ожидает',
                              style: TextStyle(
                                color:
                                    data.statuses[station.number]?.isDone ==
                                        true
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ),
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
