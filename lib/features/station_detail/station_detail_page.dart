import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/station.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/dialogs/request_dialogs.dart';
import '../../shared/dialogs/to_dialog.dart';
import '../../shared/navigation/app_page_route.dart';
import '../../shared/utils/date_format.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/station_card_content.dart';
import '../defect_acts/defect_acts_page.dart';
import '../station_info/station_info_page.dart';

final _stationProvider = FutureProvider.family<Station?, String>((
  ref,
  number,
) async {
  await ref.watch(appInitProvider.future);
  final repo = await ref.watch(stationRepositoryProvider.future);
  return repo.getByNumber(number);
});

final _maintenanceInfoProvider = FutureProvider.family<String, String>((
  ref,
  number,
) async {
  final maint = await ref.watch(maintenanceRepositoryProvider.future);
  final status = await maint.getStatus(number);
  final last = await maint.getLastDone(number);
  final parts = <String>[];
  if (status.isDone) {
    parts.add(
      'ТО в этом месяце: ${formatMaintenanceDate(status.dateDone)}'
      '${status.toType != null && status.toType!.isNotEmpty ? ' (${status.toType})' : ''}',
    );
  } else {
    parts.add('ТО в этом месяце: не выполнено');
  }
  if (last != null) {
    parts.add(
      'Последнее ТО: ${formatMaintenanceDate(last['date_done'])}'
      '${last['to_type'] != null && (last['to_type'] as String).isNotEmpty ? ' (${last['to_type']})' : ''}',
    );
  }
  return parts.join('\n');
});

class StationDetailPage extends ConsumerWidget {
  const StationDetailPage({super.key, required this.stationNumber});

  final String stationNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationAsync = ref.watch(_stationProvider(stationNumber));
    final maintText = ref.watch(_maintenanceInfoProvider(stationNumber));
    final requestsAsync = ref.watch(stationRequestsProvider(stationNumber));

    return stationAsync.when(
      data: (station) {
        if (station == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Станция не найдена')),
          );
        }
        return AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: Text('№${station.number}')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  child: StationCardContent(
                    station: station,
                    showNumberBadge: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Новая заявка',
                        icon: Icons.add_circle_outline,
                        onPressed: () =>
                            showNewRequestDialog(context, ref, stationNumber),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Информация',
                        icon: Icons.info_outline,
                        onPressed: () => Navigator.of(context).push(
                          AppPageRoute(
                            page: StationInfoPage(stationNumber: stationNumber),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppSecondaryButton(
                  label: 'Акты дефектации',
                  icon: Icons.description_outlined,
                  onPressed: () => Navigator.of(context).push(
                    AppPageRoute(
                      page: DefectActsPage(stationNumber: stationNumber),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                maintText.when(
                  data: (t) => GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              t.contains('не выполнено')
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: t.contains('не выполнено')
                                  ? AppColors.warning
                                  : AppColors.success,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Техобслуживание',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(t, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        AppSecondaryButton(
                          label: 'Отметить ТО',
                          icon: Icons.build_circle_outlined,
                          onPressed: () async {
                            await showToDialog(
                              context,
                              stationNumber: stationNumber,
                            );
                            ref.invalidate(
                              _maintenanceInfoProvider(stationNumber),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                Text('Заявки', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                requestsAsync.when(
                  data: (requests) {
                    if (requests.isEmpty) {
                      return const GlassCard(
                        child: Text(
                          'Нет открытых заявок',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return Column(
                      children: requests
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                onTap: () =>
                                    showEditRequestDialog(context, ref, r),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.requestType,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      r.description,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'от ${r.dateCreated}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (e, _) => Text(
                    'Ошибка: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => AppBackground(
        child: Scaffold(
          appBar: AppBar(title: Text('АЗС $stationNumber')),
          backgroundColor: Colors.transparent,
          body: const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      ),
      error: (e, _) => AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(),
          body: Center(child: Text('$e')),
        ),
      ),
    );
  }
}
