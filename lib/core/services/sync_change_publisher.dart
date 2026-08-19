abstract interface class SyncChangePublisher {
  Future<void> publishUpsert({required String entity, required String localPk});

  Future<void> publishUpsertPayload({
    required String entity,
    required String localPk,
    required Map<String, Object?> payload,
  });

  Future<void> publishDelete({required String entity, required String localPk});
}

abstract final class SyncEntity {
  static const stations = 'stations';
  static const requests = 'requests';
  static const maintenance = 'maintenance';
  static const stationEquipment = 'station_equipment';
  static const stationInfo = 'station_info';
  static const defectActs = 'defect_acts';
  static const equipmentOrderExports = 'equipment_order_exports';
}
