import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:ntk_map_view/ntk_map_view.dart';
import 'package:ntk_map_view/src/mobile/ntk_map_view_state_mobile.dart';
import 'package:ntk_map_view/src/models/map_camera_state.dart';

///NtkMapController for mobile versions of app
class NtkMapControllerPlatform implements NtkMapController {
  ///NtkMapController for mobile versions of app
  NtkMapControllerPlatform({required this.viewId});

  @override
  Map<LatLng, Function(LatLng point)> markers =
      <LatLng, Function(LatLng point)>{};

  @override
  Map<String, Function> markersAction = <String, Function>{};

  @override
  final String viewId;

  ///Move center camera on [point] (like panTo in leaflet)
  @override
  Future<void> goToPoint(LatLng point) async {
    await NtkMapViewState.controller
        .runJavaScript('_goToPoint(${point.latitude}, ${point.longitude});');
  }

  ///Move camera to [point] and [zoom] (like flyTo in leaflet)
  @override
  Future<void> goToPointThenZoom(LatLng point, double zoom) async {
    await NtkMapViewState.controller.runJavaScript(
      '_goToPointThenZoom(${point.latitude}, ${point.longitude}, $zoom);',
    );
  }

  ///Create marker on point with title, in this marker you may configure a button and its callback
  ///on [point]
  ///with [title]
  ///buttons with [names]
  ///and callbacks [acts]

  @override
  Future<MapMarker> addMarker(
      {required MapMarker marker, bool noCluster = false}) async {
    List<String> buttIds = <String>[];

    if (marker.popup?.buttons != null && marker.popup!.buttons!.isNotEmpty) {
      for (int index = 0; index < marker.popup!.buttons!.length; index++) {
        String id = createUniqueUid(count: 8, isNumberEnabled: false);
        buttIds.add(id);

        marker.popup!.buttons![index] = marker.popup!.buttons![index]..id = id;

        markersAction[id] = marker.popup!.buttons![index].onTap;
      }
    }

    String json = marker.toJs();
    final String safe = json.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

    await NtkMapViewState.controller
        .runJavaScript("_addMarker('$safe', $noCluster)");

    return marker;
  }

  ///Create polyline on List of [points] (also clear all previous polyline)
  @override
  Future<MapPolyline> addPolyline({required MapPolyline polyline}) async {
    final String json = polyline.toJs();
    final String safe = json.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    await NtkMapViewState.controller.runJavaScript("_createPolyline('$safe')");

    return polyline;
  }

  ///Update **[filter]** map
  @override
  Future<void> applyNewFilter(MapFilter filter) async {
    List<String> list = filter.toParameterString();

    String correctList = '[';

    for (int i = 0; i < list.length; i++) {
      correctList += "'${list[i]}', ";
    }

    correctList = correctList.substring(0, correctList.length - 2);
    correctList += ']';

    await NtkMapViewState.controller.runJavaScript(
      '_updateFilter($correctList);',
    );
  }

  ///Update current position on map
  ///This create a circle and marker with center in **[point]**
  ///Radius of circle is **[accuracy]**
  @override
  Future<void> updateCurrentPosition(LatLng point, double accuracy) async {
    await NtkMapViewState.controller.runJavaScript(
        '_updateCurrentPosition(${point.latitude}, ${point.longitude}, $accuracy)');
  }

  @override
  Future<void> removeAllMarkers() async {
    await NtkMapViewState.controller.runJavaScript('_clearAllMarkers()');
  }

  @override
  Future<void> removeMarker({required MapMarker marker}) async {
    await NtkMapViewState.controller
        .runJavaScript("_removeMarker('${marker.id}')");
  }

  @override
  Future<void> removePolyline({required MapPolyline polyline}) async {
    await NtkMapViewState.controller
        .runJavaScript("_removePolyline('${polyline.id}')");
  }

  @override
  Future<void> removeAllPolyline() async {
    await NtkMapViewState.controller.runJavaScript('_clearAllPolyline()');
  }

  @override
  Future<void> loadFontFromAsset(
      {required String fontName, required String fontPath}) async {
    await NtkMapViewState.controller
        .runJavaScript("_setNewFont('$fontName', '$fontPath')");
  }

  @override
  Future<void> goToBounds(MapBounds bounds) async {
    await NtkMapViewState.controller
        .runJavaScript("_goToBounds('${bounds.toJs()}')");
  }

  @override
  Future<MapCameraState?> getCameraState() async {
    try {
      final Object result = await NtkMapViewState.controller
          .runJavaScriptReturningResult('_getCameraStateJson()');
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
}
