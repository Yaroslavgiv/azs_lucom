import 'dart:convert';
import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'map_bounds.dart';
import 'map_marker.dart';

class NtkMapController {
  NtkMapController._({required this.viewId});

  final String viewId;
  final Map<LatLng, void Function(LatLng point)> markers = {};
  final Map<String, LatLng> _pointsById = {};

  WebViewController? _webView;

  static NtkMapController init(String? viewId) {
    return NtkMapController._(viewId: viewId ?? _createViewId());
  }

  void attach(WebViewController controller) {
    _webView = controller;
  }

  Future<void> addMarker({
    required MapMarker marker,
    bool noCluster = false,
  }) async {
    _pointsById[marker.id] = marker.point;
    final payload = {
      'id': marker.id,
      'lat': marker.point.latitude,
      'lon': marker.point.longitude,
      'title': marker.popup?.title ?? '',
      'iconUrl': marker.icon?.iconUrl,
      'width': marker.icon?.width ?? 30,
      'height': marker.icon?.height ?? 40,
      'noCluster': noCluster,
    };
    await _eval('_addMarker(${jsonEncode(payload)})');
  }

  Future<void> removeAllMarkers() async {
    _pointsById.clear();
    await _eval('_clearAllMarkers()');
  }

  Future<void> goToBounds(MapBounds bounds) async {
    if (bounds.points.isEmpty) return;
    final points = [
      for (final point in bounds.points) [point.latitude, point.longitude],
    ];
    await _eval('_goToBounds(${jsonEncode(points)})');
  }

  Future<void> goToPointThenZoom(LatLng point, double zoom) async {
    await _eval(
      '_goToPointThenZoom(${point.latitude}, ${point.longitude}, $zoom)',
    );
  }

  Future<void> updateCurrentPosition(LatLng point, double accuracy) async {
    await _eval(
      '_updateCurrentPosition(${point.latitude}, ${point.longitude}, $accuracy)',
    );
  }

  void handleBridgeMessage(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;

    final type = decoded['type'] as String?;
    if (type == 'point') {
      final id = decoded['id'] as String?;
      final lat = (decoded['lat'] as num?)?.toDouble();
      final lon = (decoded['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return;

      final point = (id != null ? _pointsById[id] : null) ?? LatLng(lat, lon);
      final callback = markers[point] ?? _callbackNear(lat, lon);
      callback?.call(point);
    }
  }

  void Function(LatLng point)? _callbackNear(double lat, double lon) {
    for (final entry in markers.entries) {
      if ((entry.key.latitude - lat).abs() < 1e-7 &&
          (entry.key.longitude - lon).abs() < 1e-7) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _eval(String js) async {
    final webView = _webView;
    if (webView == null) return;
    await webView.runJavaScript(js);
  }

  static String _createViewId() {
    final random = Random();
    final buffer = StringBuffer('map');
    for (var i = 0; i < 6; i++) {
      buffer.write(random.nextInt(10));
    }
    return buffer.toString();
  }
}
