import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/maintenance_lifecycle.dart';
import '../../core/models/maintenance_report.dart';
import '../../core/models/request_item.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/navigation/app_page_route.dart';
import '../../shared/widgets/glass_card.dart';
import '../maintenance_report/maintenance_report_page.dart';
import '../station_detail/station_detail_page.dart';

class MyWorkPage extends ConsumerWidget {
  const MyWorkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    return FutureBuilder(
      future: _load(ref, profile?.id),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Мои работы',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            if (data == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Заявки',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (data.requests.isEmpty)
                      const GlassCard(child: Text('Нет назначенных заявок'))
                    else
                      for (final item in data.requests)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            onTap: () => Navigator.of(context).push(
                              AppPageRoute(
                                page: StationDetailPage(
                                  stationNumber: item.stationNumber,
                                ),
                              ),
                            ),
                            child: Text(
                              'АЗС ${item.stationNumber} · ${item.statusLabel}\n'
                              '${item.description}\nСрок: ${item.dueDate ?? '—'}',
                            ),
                          ),
                        ),
                    const SizedBox(height: 16),
                    Text(
                      'Плановое ТО',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (data.maintenance.isEmpty)
                      const GlassCard(child: Text('Нет назначенного ТО'))
                    else
                      for (final item in data.maintenance)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            onTap: () => Navigator.of(context).push(
                              AppPageRoute(
                                page: MaintenanceReportPage(
                                  stationNumber: item.stationNumber,
                                ),
                              ),
                            ),
                            child: Text(
                              'АЗС ${item.stationNumber} · ${MaintenanceLifecycle.label(item.status)}\n'
                              'Срок: ${item.dueDate ?? '—'}'
                              '${item.reviewComment == null || item.reviewComment!.isEmpty ? '' : '\nКомментарий руководителя: ${item.reviewComment}'}',
                            ),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<({List<RequestItem> requests, List<MaintenanceRecord> maintenance})>
  _load(WidgetRef ref, String? userId) async {
    if (userId == null) {
      return (requests: <RequestItem>[], maintenance: <MaintenanceRecord>[]);
    }
    final requests = await (await ref.read(
      requestRepositoryProvider.future,
    )).getAssignedTo(userId);
    final maintenance = await (await ref.read(
      maintenanceRepositoryProvider.future,
    )).listAssignedTo(userId);
    return (requests: requests, maintenance: maintenance);
  }
}
