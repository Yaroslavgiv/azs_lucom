/// Жизненный цикл ТО за календарный месяц.
abstract final class MaintenanceLifecycle {
  static const planned = 'planned';
  static const inReview = 'in_review';
  static const accepted = 'accepted';
  static const returned = 'returned';

  /// Исторический статус «ожидает».
  static const legacyPending = 'pending';

  /// Исторический статус «выполнено» (считаем принятым).
  static const legacyDone = 'done';

  static const sqlAcceptedIn = "'accepted','done'";

  static bool isAccepted(String? status) =>
      status == accepted || status == legacyDone;

  static bool isAwaitingAcceptance(String? status) => status == inReview;

  static bool needsAttention(String? status) => status == returned;

  static String normalize(String? status) {
    final value = status ?? planned;
    return switch (value) {
      '' || legacyPending => planned,
      legacyDone => accepted,
      _ => value,
    };
  }

  static String label(String? status) => switch (normalize(status)) {
    planned => 'Запланировано',
    inReview => 'На проверке',
    accepted => 'Принято',
    returned => 'Возвращено',
    _ => status ?? 'Запланировано',
  };
}
