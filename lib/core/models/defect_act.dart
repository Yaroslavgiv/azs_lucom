class DefectAct {
  const DefectAct({
    required this.id,
    required this.stationNumber,
    required this.createdAt,
    required this.equipmentCategory,
    required this.equipmentName,
    required this.assessment,
    required this.declaredFault,
    required this.faulty,
    required this.conclusion,
    required this.renderedText,
  });

  final int id;
  final String stationNumber;
  final DateTime createdAt;
  final String equipmentCategory;
  final String equipmentName;
  final String assessment;
  final String declaredFault;
  final String faulty;
  final String conclusion;
  final String renderedText;

  static DefectAct fromMap(Map<String, Object?> m) {
    return DefectAct(
      id: (m['id'] as int?) ?? 0,
      stationNumber: (m['station_number'] as String?) ?? '',
      createdAt: DateTime.tryParse((m['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      equipmentCategory: (m['equipment_category'] as String?) ?? '',
      equipmentName: (m['equipment_name'] as String?) ?? '',
      assessment: (m['assessment'] as String?) ?? '',
      declaredFault: (m['declared_fault'] as String?) ?? '',
      faulty: (m['faulty'] as String?) ?? '',
      conclusion: (m['conclusion'] as String?) ?? '',
      renderedText: (m['rendered_text'] as String?) ?? '',
    );
  }

  Map<String, Object?> toInsertMap() {
    return {
      'station_number': stationNumber,
      'created_at': createdAt.toIso8601String(),
      'equipment_category': equipmentCategory,
      'equipment_name': equipmentName,
      'assessment': assessment,
      'declared_fault': declaredFault,
      'faulty': faulty,
      'conclusion': conclusion,
      'rendered_text': renderedText,
    };
  }
}

