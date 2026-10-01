import 'dart:js_interop' if (dart.library.io) '' as js_util;
import 'dart:js_interop_unsafe';

import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:ntk_map_view/ntk_map_view.dart' show MapMarker, MapPolyline;
import 'package:ntk_map_view/src/models/map_camera_state.dart';
import 'package:ntk_map_view/src/interfaces/ntk_map_controller_interface.dart'
    show NtkMapController;
import 'package:ntk_map_view/src/models/map_bounds.dart';
import 'package:ntk_map_view/src/models/map_filter_class.dart' show MapFilter;
import 'package:ntk_map_view/src/modules/create_unique_uid.dart'
    show createUniqueUid;
import 'package:ntk_map_view/src/utils/fonts_loader.dart';

///NtkMapController for web versions of app
class NtkMapControllerPlatform implements NtkMapController {
  NtkMapControllerPlatform({required this.viewId});

  @override
  Map<LatLng, Function(LatLng point)> markers =
      <LatLng, Function(LatLng point)>{};

  @override
  Map<String, Function> markersAction = <String, Function>{};

  @override
  final String viewId;

  void _callMethod(String methodName, List<js_util.JSAny?> args) {
    js_util.globalContext.callMethodVarArgs(
      methodName.toJS,
      <js_util.JSAny?>[viewId.toJS, ...args],
    );
  }

  ///Move center camera on **[point]** (like panTo in leaflet)
  @override
  Future<void> goToPoint(LatLng point) async {
    _callMethod('_goToPoint', <js_util.JSAny?>[
      point.latitude.toJS,
      point.longitude.toJS,
    ]);
  }

  ///Move camera to **[point]** and **[zoom]** (like flyTo in leaflet)
  @override
  Future<void> goToPointThenZoom(LatLng point, double zoom) async {
    _callMethod('_goToPointThenZoom', <js_util.JSAny?>[
      point.latitude.toJS,
      point.longitude.toJS,
      zoom.toJS,
    ]);
  }

  @override
  Future<void> goToBounds(MapBounds bounds) async {
    _callMethod('_goToBounds', <js_util.JSAny?>[bounds.toJs().toJS]);
  }

  @override
  Future<MapCameraState?> getCameraState() async {
    try {
      final Object? result =
          js_util.globalContext.callMethodVarArgs('_getCameraStateJson'.toJS, <js_util.JSAny?>[viewId.toJS])
              as Object?;
      if (result is! String || result.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(result);
      if (decoded is! Map) {
        return null;
      }

      final dynamic lat = decoded['lat'];
      final dynamic lon = decoded['lon'];
      final dynamic zoom = decoded['zoom'];
      if (lat is! num || lon is! num || zoom is! num) {
        return null;
      }

      return MapCameraState(
        center: LatLng(lat.toDouble(), lon.toDouble()),
        zoom: zoom.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  ///Create marker on point with title, in this marker you may configure a button and its callback
  ///on **[point]**
  ///with **[title]**
  ///buttons with **[names]**
  ///and callbacks **[acts]**
  @override
  Future<MapMarker> addMarker(
      {required MapMarker marker, bool noCluster = false}) async {
    if (marker.popup?.buttons != null && marker.popup!.buttons!.isNotEmpty) {
      for (int index = 0; index < marker.popup!.buttons!.length; index++) {
        final String id = createUniqueUid(count: 8, isNumberEnabled: false);

        marker.popup!.buttons![index] = marker.popup!.buttons![index]..id = id;

        markersAction[id] = marker.popup!.buttons![index].onTap;
      }
    }

    _callMethod('_addMarker', <js_util.JSAny?>[
      marker.toJs().toJS,
      noCluster.toJS,
    ]);

    return marker;
  }

  ///Create polyline on List of **[points]** (also clear all previous polyline)
  @override
  Future<MapPolyline> addPolyline({required MapPolyline polyline}) async {
    _callMethod('_createPolyline', <js_util.JSAny?>[polyline.toJs().toJS]);

    return polyline;
  }

  ///Update **[filter]** map
  @override
  Future<void> applyNewFilter(MapFilter filter) async {
    _callMethod('_updateFilter', <js_util.JSAny?>[
      <js_util.JSString>[
        ...filter.toParameterString().map((String e) => e.toJS),
      ].toJS,
    ]);
  }

  ///Update current position on map
  ///This create a circle and marker with center in **[point]**
  ///Radius of circle is **[accuracy]**
  @override
  Future<void> updateCurrentPosition(LatLng point, double accuracy) async {
    _callMethod('_updateCurrentPosition', <js_util.JSAny?>[
      point.latitude.toJS,
      point.longitude.toJS,
      accuracy.toJS,
    ]);
  }

  @override
  Future<void> removeAllMarkers() async {
    _callMethod('_clearAllMarkers', const <js_util.JSAny?>[]);
  }

  @override
  Future<void> removeMarker({required MapMarker marker}) async {
    _callMethod('_removeMarker', <js_util.JSAny?>[marker.id.toJS]);
  }

  @override
  Future<void> removePolyline({required MapPolyline polyline}) async {
    _callMethod('_removePolyline', <js_util.JSAny?>[polyline.id.toJS]);
  }

  @override
  Future<void> removeAllPolyline() async {
    _callMethod('_clearAllPolyline', const <js_util.JSAny?>[]);
  }

  @override
  Future<void> invalidateSize() async {
    _callMethod('_resizeMap', const <js_util.JSAny?>[]);
  }

  @override
  Future<void> loadFontFromAsset(
      {required String fontName, required String fontPath}) async {
    final String font = await loadFontAsBase64(fontPath);
    _callMethod('_setNewFont', <js_util.JSAny?>[
      fontName.toJS,
      font.toJS,
    ]);
  }
}
