import 'package:flutter/material.dart';

import '../../core/models/station.dart';
import '../../core/theme/app_colors.dart';
import 'station_external_maps_buttons.dart';

/// Заголовок, адрес и кнопки внешних карт для карточки станции.
class StationCardContent extends StatelessWidget {
  const StationCardContent({
    super.key,
    required this.station,
    this.compactMaps = false,
    this.showNumberBadge = false,
  });

  final Station station;
  final bool compactMaps;
  final bool showNumberBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showNumberBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppColors.gradientAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '№${station.number}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        if (showNumberBadge) const SizedBox(height: 10),
        if (station.name.isNotEmpty)
          Text(
            station.name,
            style: theme.textTheme.titleMedium,
          ),
        if (station.address.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  station.address,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        StationExternalMapsButtons(station: station, compact: compactMaps),
      ],
    );
  }
}
