import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/utils/date_format.dart';
import '../station_detail/station_detail_page.dart';

String maintenanceListTitle(String region, bool done) {
  final regionLabel = region == regionNovgorod
      ? regionLabelNovgorod
      : regionLabelSpb;
  final statusLabel = done ? 'сделаны' : 'не сделаны';
  return '$regionLabel — ТО $statusLabel';
}

class MaintenanceListPage extends ConsumerWidget {
  const MaintenanceListPage({
    super.key,
    required this.region,
    required this.done,
  });

  final String region;
  final bool done;

  void _refresh(WidgetRef ref) {
    ref.invalidate(
      maintenanceListProvider(
        MaintenanceListFilter(region: region, done: done),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = MaintenanceListFilter(region: region, done: done);
    final async = ref.watch(maintenanceListProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: Text(maintenanceListTitle(region, done)),
        actions: [
          IconButton(
            tooltip: 'Обновить список',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                done
                    ? 'Нет станций с выполненным ТО'
                    : 'Все станции с выполненным ТО',
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final item = items[i];
              final station = item.station;
              final subtitle = done
                  ? 'ТО: ${formatMaintenanceDate(item.dateDone)}'
                        '${item.toType != null && item.toType!.isNotEmpty ? ' (${item.toType})' : ''}'
                  : station.displayTitle;

              return ListTile(
                leading: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? Colors.green : Colors.orange,
                ),
                title: Text('№${station.number}'),
                subtitle: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            StationDetailPage(stationNumber: station.number),
                      ),
                    )
                    .then((_) => _refresh(ref)),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}
