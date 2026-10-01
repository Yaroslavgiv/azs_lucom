enum MapTone { done, planned, attention }

class MapStatusInput {
  const MapStatusInput({
    required this.maintenanceAccepted,
    required this.overdue,
    required this.criticalRequest,
  });

  final bool maintenanceAccepted;
  final bool overdue;
  final bool criticalRequest;
}

/// Красный статус важнее жёлтого и зелёного.
MapTone resolveMapTone(MapStatusInput input) {
  if (input.overdue || input.criticalRequest) return MapTone.attention;
  if (input.maintenanceAccepted) return MapTone.done;
  return MapTone.planned;
}

String mapToneLabel(MapTone tone) {
  switch (tone) {
    case MapTone.done:
      return 'ТО выполнено';
    case MapTone.planned:
      return 'ТО запланировано';
    case MapTone.attention:
      return 'Требуется внимание';
  }
}
