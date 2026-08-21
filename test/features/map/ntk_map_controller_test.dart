import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ntk_map_view/ntk_map_view.dart';

void main() {
  test('handleBridgeMessage invokes callback for a matching marker', () {
    final controller = NtkMapController.init(null);
    final point = LatLng(59.9386, 30.3141);
    var tapped = false;
    controller.markers[point] = (_) => tapped = true;

    controller.handleBridgeMessage(
      jsonEncode({
        'type': 'point',
        'lat': point.latitude,
        'lon': point.longitude,
      }),
    );

    expect(tapped, isTrue);
  });

  test('init creates a controller with a view id', () {
    final controller = NtkMapController.init(null);
    expect(controller.viewId, isNotEmpty);
  });
}
