import 'package:azs_domain/azs_domain.dart';

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
  required bool maintenanceDone,
  required bool highlighted,
  bool previousPeriodOverdue = false,
  bool contractualAttention = false,
}) {
  final tone = resolveMapTone(
    MapStatusInput(
      maintenanceDoneThisMonth: maintenanceDone,
      previousPeriodOverdue: previousPeriodOverdue,
      contractualOverdueOrCritical: contractualAttention || highlighted,
    ),
  );
  return markerStyleForTone(tone);
}

StationMarkerStyle markerStyleForTone(MapTone tone) {
  switch (tone) {
    case MapTone.done:
      return StationMarkerStyle.completed;
    case MapTone.attention:
      return StationMarkerStyle.highlighted;
    case MapTone.planned:
      return StationMarkerStyle.pending;
  }
}

String stationMarkerCaption({
  required bool maintenanceDone,
  required bool highlighted,
  bool overdue = false,
  bool criticalRequest = false,
}) {
  return mapToneLabel(
    resolveMapTone(
      MapStatusInput(
        maintenanceDoneThisMonth: maintenanceDone,
        previousPeriodOverdue: overdue,
        contractualOverdueOrCritical: criticalRequest || highlighted,
      ),
    ),
  );
}
