import 'package:azs_app/features/map/station_marker_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveStationMarkerStyle', () {
    test('accepted maintenance is green even if attention is set', () {
      final style = resolveStationMarkerStyle(
        maintenanceAccepted: true,
        needsAttention: true,
      );

      expect(style, StationMarkerStyle.completed);
    });

    test('returns red style for unfinished station that needs attention', () {
      final style = resolveStationMarkerStyle(
        maintenanceAccepted: false,
        needsAttention: true,
      );

      expect(style, StationMarkerStyle.highlighted);
    });

    test('returns yellow style for planned maintenance', () {
      final style = resolveStationMarkerStyle(
        maintenanceAccepted: false,
        needsAttention: false,
      );

      expect(style, StationMarkerStyle.pending);
    });
  });
}
