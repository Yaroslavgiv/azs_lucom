import 'package:azs_app/shared/utils/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMaintenanceDate', () {
    test('formats a stored maintenance timestamp', () {
      expect(formatMaintenanceDate('2026-08-19 10:30'), '10:30 19.08.2026');
    });

    test('returns a placeholder for missing values', () {
      expect(formatMaintenanceDate(null), '—');
      expect(formatMaintenanceDate(''), '—');
    });

    test('preserves an unknown legacy value', () {
      expect(formatMaintenanceDate('legacy-date'), 'legacy-date');
    });
  });
}
