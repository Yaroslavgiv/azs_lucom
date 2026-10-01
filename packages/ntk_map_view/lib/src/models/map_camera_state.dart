import 'package:latlong2/latlong.dart';

class MapCameraState {
  const MapCameraState({
    required this.center,
    required this.zoom,
  });

  final LatLng center;
  final double zoom;
}
