String currentMonthIso([DateTime? now]) {
  final value = now ?? DateTime.now();
  return '${value.year}-${value.month.toString().padLeft(2, '0')}';
}

String currentDateIso([DateTime? now]) {
  final value = now ?? DateTime.now();
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String currentDateTimeIso([DateTime? now]) {
  final value = now ?? DateTime.now();
  return '${currentDateIso(value)} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

bool isDueDateOverdue(String? dueDate, [DateTime? now]) {
  if (dueDate == null || dueDate.trim().isEmpty) return false;
  final today = currentDateIso(now);
  return dueDate.compareTo(today) < 0;
}
