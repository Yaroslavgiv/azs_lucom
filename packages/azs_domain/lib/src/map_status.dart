enum MapTone { done, planned, attention }

class MapStatusInput {
  const MapStatusInput({
    required this.maintenanceDoneThisMonth,
    this.previousPeriodOverdue = false,
    this.contractualOverdueOrCritical = false,
  });

  final bool maintenanceDoneThisMonth;
  final bool previousPeriodOverdue;
  final bool contractualOverdueOrCritical;
}

/// Красный цвет важнее зелёного: просрочка прошлого периода или
/// просроченная/критическая договорная заявка перекрывает выполненное ТО.
MapTone resolveMapTone(MapStatusInput input) {
  if (input.previousPeriodOverdue || input.contractualOverdueOrCritical) {
    return MapTone.attention;
  }
  if (input.maintenanceDoneThisMonth) return MapTone.done;
  return MapTone.planned;
}

String mapToneLabel(MapTone tone) {
  switch (tone) {
    case MapTone.done:
      return 'ТО выполнено';
    case MapTone.planned:
      return 'ТО не выполнено';
    case MapTone.attention:
      return 'Просрочено';
  }
}
