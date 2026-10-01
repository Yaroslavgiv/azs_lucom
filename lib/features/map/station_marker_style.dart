import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum StationMarkerStyle {
  completed(
    'https://storage.yandexcloud.net/eg-small-backet/markers/greenMarker-min.png',
    AppColors.success,
  ),
  highlighted(
    'https://storage.yandexcloud.net/eg-small-backet/markers/redMarker-min.png',
    AppColors.error,
  ),
  pending(
    'https://storage.yandexcloud.net/eg-small-backet/markers/yellowMarker-min.png',
    AppColors.warning,
  );

  const StationMarkerStyle(this.iconUrl, this.color);

  final String iconUrl;
  final Color color;
}

StationMarkerStyle resolveStationMarkerStyle({
  required bool maintenanceDone,
  required bool highlighted,
}) {
  if (maintenanceDone) return StationMarkerStyle.completed;
  if (highlighted) return StationMarkerStyle.highlighted;
  return StationMarkerStyle.pending;
}
