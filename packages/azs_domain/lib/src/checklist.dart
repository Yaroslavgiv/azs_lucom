class ChecklistItemDraft {
  const ChecklistItemDraft({
    required this.id,
    required this.required,
    this.result,
  });

  final String id;
  final bool required;
  final String? result;

  bool get filled => result != null && result!.trim().isNotEmpty;
}

bool checklistReadyForSubmit(Iterable<ChecklistItemDraft> items) {
  for (final item in items) {
    if (item.required && !item.filled) return false;
  }
  return true;
}
