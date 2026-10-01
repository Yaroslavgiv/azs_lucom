import 'dart:convert' show jsonEncode;

import 'package:ntk_map_view/ntk_map_view.dart';

class MapMarker {
  final String id;
  final LatLng point;
  final MapMarkerPopup? popup;
  final MapMarkerIconModel? icon;

  MapMarker({
    required this.point,
    this.popup,
    this.icon,
    String? id,
  }) : id = id ?? createUniqueUid(isNumberEnabled: false);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'point': point.toJson(),
    'popup': popup?.toMap(),
    'icon': icon?.toMap(),
  };

  String toJs() => jsonEncode(toMap());
}
