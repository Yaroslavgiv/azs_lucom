import 'package:flutter/material.dart';
import 'package:webviewimage/webviewimage.dart';

import '../../core/models/station.dart';
import '../../core/theme/app_colors.dart';
import '../../features/station_detail/station_detail_page.dart';
import '../../shared/navigation/app_page_route.dart';
import '../widgets/app_buttons.dart';
import '../widgets/station_card_content.dart';
import 'to_dialog.dart';

Future<void> showStationMarkerDialog(
  BuildContext context, {
  required Station station,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => WebViewAware(
      child: _StationBottomSheet(station: station),
    ),
  );
}

class _StationBottomSheet extends StatelessWidget {
  const _StationBottomSheet({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 32,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      station.name.isNotEmpty
                          ? '${station.name} (№${station.number})'
                          : 'АЗС №${station.number}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    StationCardContent(
                      station: station,
                      compactMaps: true,
                      showNumberBadge: false,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppSecondaryButton(
                            label: 'ТО',
                            icon: Icons.build_circle_outlined,
                            onPressed: () async {
                              Navigator.pop(context);
                              await showToDialog(
                                context,
                                stationNumber: station.number,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppPrimaryButton(
                            label: 'Заявки',
                            icon: Icons.assignment_outlined,
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                AppPageRoute(
                                  page: StationDetailPage(
                                    stationNumber: station.number,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
