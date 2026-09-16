import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/domain/time_period.dart';
import '../../core/models/station.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class WebStationsPage extends ConsumerStatefulWidget {
  const WebStationsPage({super.key});

  @override
  ConsumerState<WebStationsPage> createState() => _WebStationsPageState();
}

class _WebStationsPageState extends ConsumerState<WebStationsPage> {
  String _query = '';
  String? _region;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref.read(cloudDataServiceProvider).stations(region: _region),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final q = _query.trim().toLowerCase();
        final stations = snapshot.data!
            .where(
              (station) =>
                  q.isEmpty ||
                  station.number.contains(q) ||
                  station.name.toLowerCase().contains(q) ||
                  station.address.toLowerCase().contains(q),
            )
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Поиск по номеру или адресу',
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _region,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Все')),
                        DropdownMenuItem(
                          value: regionSpb,
                          child: Text(regionLabelSpb),
                        ),
                        DropdownMenuItem(
                          value: regionNovgorod,
                          child: Text(regionLabelNovgorod),
                        ),
                      ],
                      onChanged: (value) => setState(() => _region = value),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: stations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return GlassCard(
                    onTap: () => _openStation(station),
                    child: Text(
                      '№${station.number} · ${station.displayTitle}\n${station.address}',
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openStation(Station station) async {
    final month = currentMonthIso();
    final equipment = await ref
        .read(cloudDataServiceProvider)
        .equipmentForStation(station.number);
    final history = await ref
        .read(cloudDataServiceProvider)
        .historyForStation(station.number);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('АЗС № ${station.number}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(station.address),
                const SizedBox(height: 12),
                Text('Оборудование (${equipment.length})'),
                for (final item in equipment)
                  Text(
                    '• ${item.description} · ${item.quantity} шт. · ${item.condition}',
                  ),
                const SizedBox(height: 12),
                Text('История изменений'),
                if (history.isEmpty) const Text('Пока нет записей аудита'),
                for (final event in history.take(8))
                  Text(
                    '${event.createdAt} · ${event.actorName} · ${event.summary}',
                  ),
                const SizedBox(height: 16),
                AppPrimaryButton(
                  label: 'Принять ТО за $month',
                  onPressed: () async {
                    final profile = ref.read(currentUserProfileProvider).value;
                    await ref
                        .read(maintenanceWorkflowProvider)
                        .accept(
                          stationNumber: station.number,
                          month: month,
                          actorId: profile?.id,
                          actorName: profile?.shortName,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                AppSecondaryButton(
                  label: 'Вернуть отчёт',
                  onPressed: () async {
                    final profile = ref.read(currentUserProfileProvider).value;
                    await ref
                        .read(maintenanceWorkflowProvider)
                        .returnForRevision(
                          stationNumber: station.number,
                          month: month,
                          comment: 'Требуется дополнить отчёт',
                          actorId: profile?.id,
                          actorName: profile?.shortName,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
