import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../interfaces/ntk_view_interface.dart';
import '../mobile/ntk_map_controller_mobile.dart';
import '../models/map_camera_state.dart';

///Mobile state for widget
class NtkMapViewState extends State<NtkMapView> {
  ///[viewID] to view
  late String viewID;

  ///[controller] of map widget
  static late WebViewController controller;

  ///This a internal callback when user click on marker
  ///
  /// param:
  /// [lat] - latitude on point
  /// [lon] - longitude of point
  void increment(double lat, double lon) {
    try {
      LatLng point = LatLng(lat, lon);
      if (widget.controller!.markers.containsKey(point)) {
        widget.controller!.markers[point]!(point);
      } else {
        //widget.controller?.markers.keys.map((e) => print(e.longitude));
      }
    } catch (_) {}
  }

  ///This a internal callback when user click on button in custom marker
  ///
  /// param:
  /// [buttonId] - id of button
  void customMarkerTapButton(String buttonId) {
    try {
      if (widget.controller!.markersAction.containsKey(buttonId)) {
        widget.controller!.markersAction[buttonId]!();
      } else {
        //widget.controller?.markers.keys.map((e) => print(e.longitude));
      }
    } catch (_) {}
  }

  ///TCallback when user click on map
  ///
  /// param:
  /// [lat] - latitude of click
  /// [lon] - longitude of click
  void onMapClicked(double lat, double lon) {
    try {
      if (widget.onMapClick != null) {
        widget.onMapClick!(LatLng(lat, lon));
      }
    } catch (_) {}
  }

  ///Callback when user long click/tap on map
  ///
  /// param:
  /// [lat] - latitude of click
  /// [lon] - longitude of click
  void onMapLongClicked(double lat, double lon) {
    try {
      debugPrint('NTK_LONG_CLICK $lat $lon');
      if (widget.onMapLongClick != null) {
        widget.onMapLongClick!(LatLng(lat, lon));
      }
    } catch (_) {}
  }

  String getStyleUrl() => widget.styleUrl;

  void _handleBridgeMessage(String msg) {
    final List<String> parts = msg.split(' ');
    if (parts.isNotEmpty && parts[0] == 'moveend') {
      try {
        if (parts.length >= 4) {
          widget.onMapMoveEnd?.call(
            MapCameraState(
              center: LatLng(double.parse(parts[1]), double.parse(parts[2])),
              zoom: double.parse(parts[3]),
            ),
          );
        }
      } catch (_) {
        // Ignore parse errors.
      }
      return;
    }

    if (parts.length >= 3) {
      try {
        if (parts[0] == 'click') {
          onMapClicked(double.parse(parts[1]), double.parse(parts[2]));
          return;
        }
        if (parts[0] == 'longclick') {
          onMapLongClicked(double.parse(parts[1]), double.parse(parts[2]));
          return;
        }
        if (parts[0] == 'point') {
          increment(double.parse(parts[1]), double.parse(parts[2]));
          return;
        }
      } catch (_) {
        // Ignore parse errors.
      }
    }
    if (parts.isNotEmpty && parts[0] == 'custommarker' && parts.length >= 2) {
      customMarkerTapButton(parts[1]);
    } else if (msg.contains('ERROR_INTERNAL')) {
      debugPrint(msg);
    }
  }

  @override
  void initState() {
    if (mounted) {
      setState(() {});
    }

    viewID = widget.controller!.viewId;

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'NtkBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message.toString());
        },
      )
      ..loadFlutterAsset(widget.mapPath)
          .then(
        (_) {
          // Внедряем обработчики как на веб-версии (window.parent) — в WebView window.parent === window
          controller.runJavaScript("""
            window.__ntkEmit = function(message) {
              if (window.NtkBridge && typeof window.NtkBridge.postMessage === 'function') {
                window.NtkBridge.postMessage(message);
              } else {
                console.log(message);
              }
            };
            window.onMapCl = function(lat, lon) { window.__ntkEmit('click ' + lat + ' ' + lon); };
            window.onMapLongCl = function(lat, lon) { window.__ntkEmit('longclick ' + lat + ' ' + lon); };
            window.customCl = function(id) { window.__ntkEmit('custommarker ' + id); };
            if (typeof window.parent === 'undefined') window.parent = window;
            window.parent.onMapCl = window.onMapCl;
            window.parent.onMapLongCl = window.onMapLongCl;
            window.parent.customCl = window.customCl;
          """);
          controller.runJavaScript("console.log('HELLO From Flutter!!')");
          Future<void>.delayed(Duration(milliseconds: 500)).then((_) =>
              controller.runJavaScript("_updateMapStyle('${getStyleUrl()}')"));
          // Даём время загрузиться новому стилю карты (setStyle асинхронный) перед тем как считать карту готовой
          Future<void>.delayed(Duration(milliseconds: 1500)).then((_) =>
              WidgetsBinding.instance.addPostFrameCallback((_) => widget
                  .onCreateEnd
                  ?.call(widget.controller! as NtkMapControllerPlatform)));
          controller.setOnConsoleMessage((JavaScriptConsoleMessage message) {
            _handleBridgeMessage(message.message.toString());
          });
        },
      );

    super.initState();
  }

  Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers() {
    if (!widget.embeddedInScrollView) {
      return const <Factory<OneSequenceGestureRecognizer>>{};
    }

    return <Factory<OneSequenceGestureRecognizer>>{
      Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size screen = MediaQuery.of(context).size;
        final double width = constraints.maxWidth.isFinite ? constraints.maxWidth : screen.width;
        final double height = constraints.maxHeight.isFinite ? constraints.maxHeight : screen.height;

        return SizedBox(
          width: width,
          height: height,
          child: WebViewWidget(
            controller: controller,
            gestureRecognizers: _gestureRecognizers(),
          ),
        );
      },
    );
  }
}
