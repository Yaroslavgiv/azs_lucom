/// Статусы заявки. Значения `open`/`closed` сохранены как совместимость.
abstract final class RequestStatus {
  static const created = 'new';
  static const assigned = 'assigned';
  static const inProgress = 'in_progress';
  static const done = 'done';
  static const overdue = 'overdue';

  /// Исторический статус «открыта».
  static const legacyOpen = 'open';

  /// Исторический статус «закрыта».
  static const legacyClosed = 'closed';

  static const activeValues = [
    created,
    assigned,
    inProgress,
    overdue,
    legacyOpen,
  ];

  static const closedValues = [done, legacyClosed];

  static const sqlActiveIn = "'new','assigned','in_progress','overdue','open'";

  static bool isActive(String? status) =>
      activeValues.contains(status ?? created);

  static bool isClosed(String? status) =>
      closedValues.contains(status ?? created);

  static String label(String? status) => switch (status) {
    created || legacyOpen => 'Новая',
    assigned => 'Назначена',
    inProgress => 'В работе',
    overdue => 'Просрочена',
    done || legacyClosed => 'Выполнена',
    _ => status ?? 'Новая',
  };

  static String normalize(String? status) {
    final value = status ?? created;
    return switch (value) {
      legacyOpen || '' => created,
      legacyClosed => done,
      _ => value,
    };
  }
}
