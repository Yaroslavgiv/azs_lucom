import 'package:latlong2/latlong.dart';

class MapMarkerPopup {
  const MapMarkerPopup({required this.title});

  final String title;
}

class MapMarkerIconModel {
  const MapMarkerIconModel({
    required this.iconUrl,
    required this.width,
    required this.height,
  });

  final String iconUrl;
  final double width;
  final double height;
}

class MapMarker {
  const MapMarker({
    required this.id,
    required this.point,
    this.popup,
    this.icon,
  });

  final String id;
  final LatLng point;
  final MapMarkerPopup? popup;
  final MapMarkerIconModel? icon;
}
