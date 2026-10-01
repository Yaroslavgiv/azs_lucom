import 'package:azs_app/features/map/station_marker_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveStationMarkerStyle', () {
    test('attention overrides accepted maintenance', () {
      final style = resolveStationMarkerStyle(
        maintenanceDone: true,
        highlighted: true,
      );

      expect(style, StationMarkerStyle.highlighted);
      expect(
        stationMarkerCaption(maintenanceDone: true, highlighted: true),
        'Просрочено',
      );
    });

    test('returns highlighted style for an unfinished priority station', () {
      final style = resolveStationMarkerStyle(
        maintenanceDone: false,
        highlighted: true,
      );

      expect(style, StationMarkerStyle.highlighted);
    });

    test('returns pending style for a regular unfinished station', () {
      final style = resolveStationMarkerStyle(
        maintenanceDone: false,
        highlighted: false,
      );

      expect(style, StationMarkerStyle.pending);
    });
  });
}
