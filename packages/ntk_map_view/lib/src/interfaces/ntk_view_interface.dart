import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_camera_state.dart';
import '../modules/create_unique_uid.dart';
import '../web/ntk_map_controller_web.dart' if (dart.library.io) '../mobile/ntk_map_controller_mobile.dart' as ctl;
import '../web/ntk_map_view_state_web.dart' if (dart.library.io) '../mobile/ntk_map_view_state_mobile.dart' as state;
import 'ntk_map_controller_interface.dart';

export 'package:latlong2/latlong.dart';

///Widget to display a map this have a **[onCreateStart]**, **[onCreateEnd]**, **[onMapClick]**, **[onMapLongClick]** callbacks
///Also may configure path to map in **[mapPath]**
///And add a **[controller]**
class NtkMapView extends StatefulWidget {
  ///Widget to display a map this have a **[onCreateStart]**, **[onCreateEnd]**, **[onMapClick]**, **[onMapLongClick]** callbacks
  ///Also may configure path to map in **[mapPath]**
  ///And add a **[controller]**
  NtkMapView({
    super.key,
    this.onCreateStart,
    this.onCreateEnd,
    this.onMapClick,
    this.onMapLongClick,
    this.onMapMoveEnd,
    this.embeddedInScrollView = false,
    this.styleUrl = 'https://tiles.openfreemap.org/styles/bright',
    this.mapPath = 'packages/ntk_map_view/lib/assets/map.html',
    NtkMapController? mapController,
  }) : controller = mapController ?? ctl.NtkMapControllerPlatform(viewId: createUniqueUid(count: 6));

  /// **[onCreateStart]** Callback when map start create
  final Function()? onCreateStart;

  /// **[onCreateEnd]** Callback when map create end(remember that callback for create, this not show end of full init map)
  ///
  /// returned a **[NtkMapControllerInterface]** map controller
  final Function(NtkMapController)? onCreateEnd;

  /// **[onMapClick]** Callback when user click on map, returned a point [LatLng]
  final Function(LatLng)? onMapClick;

  /// **[onMapLongClick]** Callback when user long click/tap on map, returned a point [LatLng]
  final Function(LatLng)? onMapLongClick;

  /// **[onMapMoveEnd]** Callback when user finished panning/zooming the map
  final void Function(MapCameraState camera)? onMapMoveEnd;

  /// When true, map claims drag gestures inside scrollable parents (e.g. order details).
  final bool embeddedInScrollView;

  /// **[controller]** for this map
  late final NtkMapController? controller;

  /// **[mapPath]** Map path
  final String mapPath;

  /// **[styleUrl]** Map style
  /// default https://tiles.openfreemap.org/styles/bright
  final String styleUrl;

  @override
  State<NtkMapView> createState() => state.NtkMapViewState();
}
