import 'package:flutter/material.dart';

import '../../core/models/station.dart';
import '../../core/services/external_maps_service.dart';
import 'app_buttons.dart';

/// Кнопки открытия маршрута в Яндекс.Картах и 2ГИС.
class StationExternalMapsButtons extends StatelessWidget {
  const StationExternalMapsButtons({
    super.key,
    required this.station,
    this.compact = false,
  });

  final Station station;
  final bool compact;

  Future<void> _open(
    BuildContext context,
    Future<bool> Function() launch,
  ) async {
    final ok = await launch();
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть карты')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!station.hasCoordinates) {
      return Text(
        'Координаты не заданы — маршрут недоступен',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final lat = station.lat!;
    final lon = station.lon!;

    if (compact) {
      return Row(
        children: [
          Expanded(
            child: AppSecondaryButton(
              label: '2ГИС',
              expand: true,
              onPressed: () => _open(
                context,
                () => ExternalMapsService.openTwoGisRoute(lat, lon),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppPrimaryButton(
              label: 'Яндекс',
              expand: true,
              onPressed: () => _open(
                context,
                () => ExternalMapsService.openYandexRoute(lat, lon),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPrimaryButton(
          label: 'Маршрут в Яндекс.Картах',
          icon: Icons.navigation_outlined,
          onPressed: () => _open(
            context,
            () => ExternalMapsService.openYandexRoute(lat, lon),
          ),
        ),
        const SizedBox(height: 8),
        AppSecondaryButton(
          label: 'Маршрут в 2ГИС',
          icon: Icons.map_outlined,
          onPressed: () => _open(
            context,
            () => ExternalMapsService.openTwoGisRoute(lat, lon),
          ),
        ),
      ],
    );
  }
}
