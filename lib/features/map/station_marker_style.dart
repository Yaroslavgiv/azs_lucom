enum StationMarkerStyle {
  completed(
    'https://storage.yandexcloud.net/eg-small-backet/markers/greenMarker-min.png',
  ),
  highlighted(
    'https://storage.yandexcloud.net/eg-small-backet/markers/redMarker-min.png',
  ),
  pending(
    'https://storage.yandexcloud.net/eg-small-backet/markers/yellowMarker-min.png',
  );

  const StationMarkerStyle(this.iconUrl);

  final String iconUrl;
}

StationMarkerStyle resolveStationMarkerStyle({
  required bool maintenanceAccepted,
  required bool needsAttention,
}) {
  if (maintenanceAccepted) return StationMarkerStyle.completed;
  if (needsAttention) return StationMarkerStyle.highlighted;
  return StationMarkerStyle.pending;
}
