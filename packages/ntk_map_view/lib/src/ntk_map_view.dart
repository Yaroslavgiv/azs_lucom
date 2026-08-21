import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ntk_map_controller.dart';

class NtkMapView extends StatefulWidget {
  const NtkMapView({
    super.key,
    required this.mapController,
    this.mapPath = 'packages/ntk_map_view/lib/assets/map_mobile.html',
    this.styleUrl,
    this.onCreateEnd,
  });

  final NtkMapController mapController;
  final String mapPath;
  final String? styleUrl;
  final FutureOr<void> Function(NtkMapController controller)? onCreateEnd;

  @override
  State<NtkMapView> createState() => _NtkMapViewState();
}

class _NtkMapViewState extends State<NtkMapView> {
  late final WebViewController _webViewController;
  var _bootstrapped = false;
  var _readyNotified = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'NtkMapBridge',
        onMessageReceived: (message) => _onBridgeMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => _bootstrap()),
      );
    widget.mapController.attach(_webViewController);
    _webViewController.loadFlutterAsset(widget.mapPath);
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final options = {
      'styleUrl': widget.styleUrl,
      'lat': 55.0,
      'lon': 30.0,
      'zoom': 4.0,
    };
    await _webViewController.runJavaScript('_initMap(${jsonEncode(options)})');
  }

  void _onBridgeMessage(String raw) {
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      } else if (decoded is Map) {
        payload = decoded.cast<String, dynamic>();
      }
    } catch (_) {
      return;
    }
    if (payload == null) return;

    if (payload['type'] == 'ready' && !_readyNotified) {
      _readyNotified = true;
      final onCreateEnd = widget.onCreateEnd;
      if (onCreateEnd != null) {
        unawaited(Future.sync(() => onCreateEnd(widget.mapController)));
      }
      return;
    }

    widget.mapController.handleBridgeMessage(raw);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }
}
