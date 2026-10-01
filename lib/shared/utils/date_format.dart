import 'package:intl/intl.dart';

String formatMaintenanceDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  try {
    final dt = DateFormat('yyyy-MM-dd HH:mm').parse(raw);
    return DateFormat('HH:mm dd.MM.yyyy').format(dt);
  } catch (_) {
    return raw;
  }
}

String formatRuDateTime(DateTime value) {
  return DateFormat('dd.MM.yyyy HH:mm').format(value.toLocal());
}
