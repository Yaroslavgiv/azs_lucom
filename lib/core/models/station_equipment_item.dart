class StationEquipmentItem {
  const StationEquipmentItem({
    required this.id,
    required this.stationNumber,
    required this.category,
    required this.description,
  });

  final int id;
  final String stationNumber;
  final String category;
  final String description;

  static StationEquipmentItem fromMap(Map<String, Object?> m) {
    return StationEquipmentItem(
      id: (m['id'] as int?) ?? 0,
      stationNumber: (m['station_number'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
    );
  }
}

