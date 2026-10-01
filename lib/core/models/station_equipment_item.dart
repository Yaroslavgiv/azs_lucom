class StationEquipmentItem {
  const StationEquipmentItem({
    required this.id,
    required this.stationNumber,
    required this.category,
    required this.description,
    this.model = '',
    this.quantity = 1,
    this.serialNumber,
    this.condition = '',
  });

  final int id;
  final String stationNumber;
  final String category;
  final String description;
  final String model;
  final int quantity;
  final String? serialNumber;
  final String condition;

  static StationEquipmentItem fromMap(Map<String, Object?> m) {
    return StationEquipmentItem(
      id: (m['id'] as int?) ?? 0,
      stationNumber: (m['station_number'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      model: (m['model'] as String?) ?? '',
      quantity: (m['quantity'] as int?) ?? 1,
      serialNumber: m['serial_number'] as String?,
      condition: (m['condition'] as String?) ?? '',
    );
  }
}
