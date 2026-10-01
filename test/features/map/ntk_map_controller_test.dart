import 'package:flutter_test/flutter_test.dart';
import 'package:ntk_map_view/ntk_map_view.dart';

void main() {
  test('init creates a controller with a view id', () {
    final controller = NtkMapController.init(null);
    expect(controller.viewId, isNotEmpty);
  });

  test('markers map accepts callback for a point', () {
    final controller = NtkMapController.init(null);
    final point = LatLng(59.9386, 30.3141);
    var tapped = false;
    controller.markers[point] = (_) => tapped = true;

    controller.markers[point]!(point);
    expect(tapped, isTrue);
  });
}
