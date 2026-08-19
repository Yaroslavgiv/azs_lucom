import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/navigation/app_page_route.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../export/maintenance_list_page.dart';
import '../station_detail/station_detail_page.dart';

class StationsListPage extends ConsumerWidget {
  const StationsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Станции',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceInset,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  gradient: AppColors.gradientAccent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: regionLabelSpb),
                  Tab(text: regionLabelNovgorod),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: TabBarView(
              children: [
                _StationList(region: regionSpb),
                _StationList(region: regionNovgorod),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StationList extends ConsumerWidget {
  const _StationList({required this.region});

  final String region;

  void _openMaintenanceList(BuildContext context, bool done) {
    Navigator.of(context).push(
      AppPageRoute(
        page: MaintenanceListPage(region: region, done: done),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stationsByRegionProvider(region));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: async.when(
            data: (stations) {
              if (stations.isEmpty) {
                return const Center(
                  child: Text(
                    'Нет станций',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: stations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final s = stations[i];
                  return StaggeredFadeIn(
                    index: i,
                    child: GlassCard(
                      onTap: () => Navigator.of(context).push(
                        AppPageRoute(
                          page: StationDetailPage(stationNumber: s.number),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradientAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s.number.length > 4
                                  ? s.number.substring(s.number.length - 2)
                                  : s.number,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '№${s.number} — ${s.displayTitle}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (s.address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    s.address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            s.hasCoordinates
                                ? Icons.place
                                : Icons.place_outlined,
                            color: s.hasCoordinates
                                ? AppColors.success
                                : AppColors.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (e, _) => Center(
              child: Text(
                'Ошибка: $e',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
        _MaintenanceActionBar(
          onDone: () => _openMaintenanceList(context, true),
          onPending: () => _openMaintenanceList(context, false),
        ),
      ],
    );
  }
}

class _MaintenanceActionBar extends StatelessWidget {
  const _MaintenanceActionBar({required this.onDone, required this.onPending});

  final VoidCallback onDone;
  final VoidCallback onPending;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                style: style,
                onPressed: onDone,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Сделаны'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                style: style,
                onPressed: onPending,
                icon: const Icon(Icons.radio_button_unchecked, size: 18),
                label: const Text('Не сделаны'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
