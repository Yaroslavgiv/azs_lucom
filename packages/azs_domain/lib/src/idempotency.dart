/// Ключ идемпотентности команды сервисного слоя.
String workCommandKey({
  required String entity,
  required String localId,
  required String action,
  required int revision,
}) {
  return '$entity:$localId:$action:$revision';
}

/// Ключ уведомления: повтор того же события не создаёт вторую запись.
String notificationEventKey({
  required String event,
  required String entityId,
  required String recipientId,
}) {
  return '$event:$entityId:$recipientId';
}

/// Корреляционный идентификатор журнала без секретов.
String correlationId({
  required String entity,
  required String localId,
  required DateTime at,
}) {
  return '$entity:$localId:${at.toUtc().millisecondsSinceEpoch}';
}

/// Убирает из текста журнала токены и пароли.
String redactLog(String message) {
  final patterns = [
    RegExp(r'authorization:\s*\S+(?:\s+\S+)?', caseSensitive: false),
    RegExp(r'bearer\s+\S+', caseSensitive: false),
    RegExp('(token["\\s:=]+)[^\\s",}]+', caseSensitive: false),
    RegExp('(password["\\s:=]+)[^\\s",}]+', caseSensitive: false),
    RegExp('(secret["\\s:=]+)[^\\s",}]+', caseSensitive: false),
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
  ];
  var result = message;
  for (final pattern in patterns) {
    result = result.replaceAllMapped(pattern, (match) {
      if (match.groupCount >= 1 && match.group(1) != null) {
        return '${match.group(1)}[redacted]';
      }
      return '[redacted]';
    });
  }
  return result;
}
