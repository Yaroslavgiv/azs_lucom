import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/domain/maintenance_lifecycle.dart';
import '../../core/domain/time_period.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class WebReportsPage extends ConsumerStatefulWidget {
  const WebReportsPage({super.key});

  @override
  ConsumerState<WebReportsPage> createState() => _WebReportsPageState();
}

class _WebReportsPageState extends ConsumerState<WebReportsPage> {
  String? _region;
  String? _status = MaintenanceLifecycle.accepted;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref
          .read(cloudDataServiceProvider)
          .maintenanceExportRows(region: _region, status: _status),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String?>(
                    value: _region,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Все регионы')),
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
                  DropdownButton<String?>(
                    value: _status,
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Все статусы ТО'),
                      ),
                      DropdownMenuItem(
                        value: MaintenanceLifecycle.accepted,
                        child: Text('Только принятые ТО'),
                      ),
                      DropdownMenuItem(
                        value: MaintenanceLifecycle.inReview,
                        child: Text('На проверке'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                  AppPrimaryButton(
                    label: _busy ? 'Формирование…' : 'Скачать XLSX',
                    expand: false,
                    onPressed: _busy ? null : () => _export(rows),
                  ),
                  Text(
                    'Сформировано ${currentDateTimeIso()} · строк: ${rows.length}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('АЗС')),
                    DataColumn(label: Text('Дата ТО')),
                    DataColumn(label: Text('Исполнитель')),
                    DataColumn(label: Text('Результат')),
                  ],
                  rows: [
                    for (final row in rows.take(40))
                      DataRow(
                        cells: [
                          DataCell(Text('${row['station_number']}')),
                          DataCell(Text('${row['date_done'] ?? ''}')),
                          DataCell(Text('${row['assignee_name'] ?? ''}')),
                          DataCell(Text('${row['result'] ?? row['status']}')),
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

  Future<void> _export(List<Map<String, Object?>> rows) async {
    setState(() => _busy = true);
    try {
      final exporter = await ref.read(exportServiceProvider.future);
      await exporter.shareRows(
        filename: 'ТО.xlsx',
        sheetName: 'ТО',
        headers: [
          'region',
          'station_number',
          'name',
          'address',
          'status',
          'date_done',
          'assignee_name',
          'result',
        ],
        rows: rows,
        emptyMessage: 'Нет данных по выбранным фильтрам',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
