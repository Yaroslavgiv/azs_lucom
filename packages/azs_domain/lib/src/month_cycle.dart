class ServiceMonth {
  const ServiceMonth(this.year, this.month);

  final int year;
  final int month;

  String get key => '$year-${month.toString().padLeft(2, '0')}';
}

/// Календарный месяц обслуживания в Europe/Moscow (UTC+3, без летнего времени).
ServiceMonth moscowServiceMonth(DateTime instant) {
  final moscow = instant.toUtc().add(const Duration(hours: 3));
  return ServiceMonth(moscow.year, moscow.month);
}

bool isEarlierServiceMonth(String monthKey, ServiceMonth current) {
  final parts = monthKey.split('-');
  if (parts.length < 2) return false;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return false;
  return year < current.year || (year == current.year && month < current.month);
}

bool maintenanceCountsAsDone(String? workflow, String? legacyStatus) {
  return workflow == 'done' || workflow == 'accepted' || legacyStatus == 'done';
}

class ContractRule {
  const ContractRule({
    required this.category,
    required this.version,
    this.durationHours,
    this.requiresReview = false,
    this.active = true,
  });

  final String category;
  final int version;
  final int? durationHours;
  final bool requiresReview;
  final bool active;
}

/// Срок не выдумывается: без положительной длительности в правиле `dueAt` пуст.
DateTime? contractualDueAt(DateTime createdAt, int? durationHours) {
  if (durationHours == null || durationHours <= 0) return null;
  return createdAt.toUtc().add(Duration(hours: durationHours));
}
