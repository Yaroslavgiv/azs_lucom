import 'package:latlong2/latlong.dart';
import 'package:ntk_map_view/ntk_map_view.dart'
    show MapMarker, MapPolyline, MapFilter, createUniqueUid;
import 'package:ntk_map_view/src/models/map_bounds.dart';
import 'package:ntk_map_view/src/models/map_camera_state.dart';
import '../mobile/ntk_map_controller_mobile.dart'
    if (dart.library.html) '../web/ntk_map_controller_web.dart'
    if (dart.library.js_interop) '../web/ntk_map_controller_web.dart';

///Interface to Ntk map controller
abstract class NtkMapController {
  ///Interface to Ntk map controller
  ///
  ///We need to put [viewId] to avoid unhandled error when init
  NtkMapController({required this.viewId});

  ///Create a controller for platform
  static NtkMapController init(String? viewId) {
    return NtkMapControllerPlatform(
        viewId: viewId ?? createUniqueUid(count: 6));
  }

  ///viewId of frame
  final String viewId;

  ///Markers id and callbacks(for custom markers)
  Map<String, Function> markersAction = <String, Function>{};

  ///Markers point and callback
  Map<LatLng, Function(LatLng point)> markers =
      <LatLng, Function(LatLng point)>{};

  ///Move center camera on [point] (like panTo in leaflet)
  Future<void> goToPoint(LatLng point);

  ///Move camera to [point] and [zoom] (like flyTo in leaflet)
  Future<void> goToPointThenZoom(LatLng point, double zoom);

  ///Move camera to [bounds] and auto zoomed
  Future<void> goToBounds(MapBounds bounds);

  ///Current map camera center and zoom level
  Future<MapCameraState?> getCameraState();

  ///Create marker on point with title, in this marker you may configure a button and its callback
  ///on [point]
  ///with [title]
  ///buttons with [names]
  ///and callbacks [acts]
  Future<MapMarker> addMarker(
      {required MapMarker marker, bool noCluster = false});

  ///Create polyline on List of [points] (also clear all previous polyline)
  Future<MapPolyline> addPolyline({required MapPolyline polyline});

  ///Remove specific [polyline]
  Future<void> removePolyline({required MapPolyline polyline});

  ///Remove all polyline
  Future<void> removeAllPolyline();

  ///Apply a new map **[filter]**
  Future<void> applyNewFilter(MapFilter filter);

  ///Update current position on map
  ///This create a circle and marker with center in **[point]**
  ///Radius of circle is **[accuracy]**
  Future<void> updateCurrentPosition(LatLng point, double accuracy);

  ///Remove all Markers
  Future<void> removeAllMarkers();

  ///Remove [marker]
  Future<void> removeMarker({required MapMarker marker});

  Future<void> loadFontFromAsset(
      {required String fontName, required String fontPath});
}
