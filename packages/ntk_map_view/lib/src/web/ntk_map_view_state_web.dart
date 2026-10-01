import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' if (dart.library.io) '' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as html;

import '../interfaces/ntk_view_interface.dart';
import '../models/map_camera_state.dart';
import '../web/ntk_map_controller_web.dart';

/// На Flutter Web ассеты лежат в `/assets/...` относительно origin.
/// `Uri.base` на вебе зависит от `<base href>` и текущего пути SPA; в части браузеров
/// и сценариев (прямой заход по deep link, редиректы, устаревший index.html в кэше)
/// это давало неверный URL iframe → сервер отдавал 404 только у части пользователей.
String _resolveMapUrl(String mapPath) {
  if (mapPath.startsWith('http://') || mapPath.startsWith('https://')) {
    return mapPath;
  }
  final String normalized =
      mapPath.startsWith('/') ? mapPath.substring(1) : mapPath;
  final String origin = html.window.location.origin;
  return '$origin/assets/$normalized';
}

///Web state for widget
@JSExport()
class NtkMapViewState extends State<NtkMapView> {
  late String viewID;

  ///Internal callback when user click on map
  ///
  /// param:
  /// **[lat]** - latitude on point
  /// **[lon]** - longitude of point
  @JSExport()
  void onMapCl(double lat, double lon) {
    if (widget.onMapClick != null) {
      widget.onMapClick!(LatLng(lat, lon));
    }
  }

  ///Internal callback when user long click/tap on map
  ///
  /// param:
  /// **[lat]** - latitude on point
  /// **[lon]** - longitude of point
  @JSExport()
  void onMapLongCl(double lat, double lon) {
    if (widget.onMapLongClick != null) {
      widget.onMapLongClick!(LatLng(lat, lon));
    }
  }

  ///Internal callback when user click on markers button
  ///
  /// param:
  /// **[buttonId]** - id of clicked button
  @JSExport()
  void customCl(String buttonId) {
    widget.controller!.markersAction[buttonId]!();
  }

  @JSExport()
  void onCreatedEnd() {
    widget.onCreateEnd?.call(widget.controller! as NtkMapControllerPlatform);
  }

  @JSExport()
  void onMapMoveEnd(double lat, double lon, double zoom) {
    widget.onMapMoveEnd?.call(
      MapCameraState(
        center: LatLng(lat, lon),
        zoom: zoom,
      ),
    );
  }

  ///This a internal callback when user click on marker
  ///
  /// param:
  /// **[lat]** - latitude on point
  /// **[lon]** - longitude of point
  @JSExport()
  void increment(double lat, double lon) {
    try {
      LatLng point = LatLng(lat, lon);

      if (widget.controller!.markers.containsKey(point)) {
        widget.controller!.markers[point]!(point);
      } else {}
    } catch (_) {}
  }

  /// Get style url from widget to map
  @JSExport()
  String getStyleUrl() => widget.styleUrl;

  @override
  void initState() {
    if (mounted) {
      setState(() {});
    }

    viewID = widget.controller!.viewId;

    if (widget.onCreateStart != null) widget.onCreateStart!();

    ui.platformViewRegistry.registerViewFactory(viewID, (int id) {
      globalContext.setProperty('onMapCl'.toJS, onMapCl.toJS);
      globalContext.setProperty('onMapLongCl'.toJS, onMapLongCl.toJS);
      globalContext.setProperty('customCl'.toJS, customCl.toJS);
      globalContext.setProperty('onCreatedEnd'.toJS, onCreatedEnd.toJS);
      globalContext.setProperty('onMapMoveEnd'.toJS, onMapMoveEnd.toJS);
      globalContext.setProperty('getStyleUrl'.toJS, getStyleUrl.toJS);

      // Явные style.width/style.height снимают предупреждение движка Flutter Web
      // о platform view без размеров (атрибуты width/height на iframe недостаточны).
      return html.HTMLIFrameElement()
        ..id = viewID
        ..src = _resolveMapUrl(widget.mapPath)
        ..style.border = 'none'
        ..style.display = 'block'
        ..style.width = '100%'
        ..style.height = '100%';
    });

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size screen = MediaQuery.of(context).size;
        final double width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : screen.width;
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screen.height;

        return SizedBox(
          width: width,
          height: height,
          child: HtmlElementView(viewType: viewID),
        );
      },
    );
  }
}
