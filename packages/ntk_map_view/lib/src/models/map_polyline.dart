import 'dart:convert';

import 'package:ntk_map_view/ntk_map_view.dart' show LatLng;
import 'package:ntk_map_view/src/modules/create_unique_uid.dart' show createUniqueUid;

class MapPolyline {
  final String id;
  final List<LatLng> points;

  MapPolyline({required this.points, String? id}) : id = id ?? createUniqueUid(count: 8, isNumberEnabled: false);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'points': points.map((LatLng e) => <double>[e.longitude, e.latitude]).toList(),
  };

  String toJs() => JsonEncoder().convert(toMap());
}