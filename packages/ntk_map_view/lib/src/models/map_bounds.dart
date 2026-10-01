import 'dart:convert';
import 'dart:math' as math;

import 'package:ntk_map_view/ntk_map_view.dart' show LatLng;

class MapBounds {
  final List<LatLng> points;

  MapBounds({required this.points});

  Map<String, dynamic> toMap() => <String, dynamic>{
        'points': points.map((LatLng e) => <double>[e.longitude, e.latitude]).toList(),
      };

  Map<String, dynamic> toMapWithCorrectBounds() {
    if (points.isEmpty) return <String, dynamic>{'points': <double>[]};

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return <String, dynamic>{
      'points': <List<double>>[
        <double>[minLng, minLat],
        <double>[maxLng, maxLat],
      ],
    };
  }

  String toJs() => JsonEncoder().convert(toMapWithCorrectBounds());
}
