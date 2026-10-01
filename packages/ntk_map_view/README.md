![Pub Points](https://img.shields.io/pub/points/ntk_map_view)
![Pub Publisher](https://img.shields.io/pub/publisher/ntk_map_view)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/NOTKATEAMmainAndroidDeveloper/NtkMapView)


Crossplatform Flutter map widget, powered with MapLibre GL JS

> **This package in early development**
>
> *Insert the user's personal data at your own risk, as on the WEB version this may lead to data theft. Be cautious when using such data and do so at your own risk. We are not responsible for data loss.*

>Supported **WASM**

## Usage map

If you need only a blank map create a widget
```dart
import 'package:ntk_map_view/ntk_map_view.dart';

NtkMapView();
```
<br/>

You may a configure Html file you used to map
```dart
NtkMapView(mapPath: 'assets/map.html');
```

<br/>

If you need to full control with map, then you need to create a map controller in you initState()
<br/>
Param is viewId, you may set null if you dont need customize it
```dart
NtkMapController ntkMapController = NtkMapController.init(null);
```

Then add you controller to you map widget
```dart
NtkMapView(mapController: ntkMapController,);
```
<br/>
Also you may configure callbacks for map

## Map callbacks
You may get callback on map create start
```dart
NtkMapView(
  onCreateStart: (){

  },
);
```
<br/>
You may get callback on map create end, this callback return used controller

```dart
NtkMapView(
  onCreateEnd: (controller){
    
  },
);
```

<br/>
You may get callback on user tap on map, this callback returned a point on map (LatLng)

```dart
NtkMapView(
  onMapClick: (point) async {
    
  },
);
```

## Work with controller
for now moment controller have a next method:

**addMarker({required MapMarker marker})**
<br/> Add a marker on the map

**goToPoint(LatLng point)**
<br/> Move center camera on point(like panTo in leaflet)

**goToPointThenZoom(LatLng point, double zoom)**
<br/> Move camera and zoom to point(like flyTo in leaflet)

**addPolyline({required MapPolyline polyline})**
<br/> Create polyline on List of points(also clear all previous polyline)

**updateCurrentPosition(LatLng point, double accuracy);**
<br/> Update current position on map. This create a circle and marker with center in **[point]**. Radius of circle is **[accuracy]** **FOR NOW NOT IMPLEMENTED ON MOBILE**

**removeAllMarkers();**
<br/> Remove all markers on the map

**removeMarker({required MapMarker marker});**
<br/> Remove marker on the map

## Map filter

Use in you controller method
**applyNewFilter(MapFilter filter);**
<br/><br/>
MapFilter fields (*above a default value*):
```dart
  int blur = 0;
  double invert = 0;
  double grayscale = 0;
  double bright = 1;
  double contrast = 1;
  int hue = 0;
  double opacity = 1;
  double saturate = 1;
  double sepia = 0;
```

## Work with controller extended
### addMarker({required MapMarker marker})
simple example
```dart
MapMarker marker = await ntkMapController.addMarker(
  MapMarker(
    // point is required. LatLng
    point: point,
    // additional popup
    popup: MapMarkerPopup(
      title: 'Point Number $currentMarkersCount',
      content: [MapMarkerContent(title: 'Simple content', description: 'Simple description')],
      imageUrls: ['your image url'],
      buttons: [
        MapButton(
          width: 100,
          height: 40,
          title: 'Go to point',
          onTap: () {
            ntkMapController.goToPoint(point);
          },
        ),
        MapButton(
          width: 100,
          height: 40,
          borderRadius: 15,
          textColor: Color.fromARGB(255, 255, 255, 255),
          backgroundColor: Color.fromARGB(255, 255, 0, 150),
          title: 'Go to point animated',
          onTap: () {
            ntkMapController.goToPointThenZoom(point, 8);
          },
        ),
      ],
    ),
  ),
);
```
### createPolyline({required MapPolyline polyline})
simple example
```dart
MapPolyline polyline = await ntkMapController.addPolyline(
  MapPolyline(
    points: points,
  ),
);
```
