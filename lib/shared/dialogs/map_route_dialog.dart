import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:webviewimage/webviewimage.dart';

import '../../core/services/external_maps_service.dart';

Future<void> showMapRouteDialog(BuildContext context, LatLng point) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => WebViewAware(
      child: AlertDialog(
        title: const Text('Маршрут'),
        content: const Text('Открыть навигатор?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              await ExternalMapsService.openYandexRoute(
                point.latitude,
                point.longitude,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Яндекс'),
          ),
          TextButton(
            onPressed: () async {
              await ExternalMapsService.openTwoGisRoute(
                point.latitude,
                point.longitude,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('2ГИС'),
          ),
        ],
      ),
    ),
  );
}
