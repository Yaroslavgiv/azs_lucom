import 'package:ntk_map_view/ntk_map_view.dart' show MapButton;
import 'package:ntk_map_view/src/models/marker/map_marker_content_model.dart' show MapMarkerContent;

class MapMarkerPopup {
  final String? title;
  final String? description;
  final String? fontName;
  final List<String>? imageUrls;
  final List<MapMarkerContent>? content;
  final List<MapButton>? buttons;
  final MapMarkerConstraints? constraints;

  MapMarkerPopup({
    this.title,
    this.description,
    this.fontName,
    this.content,
    this.buttons,
    this.imageUrls,
    this.constraints,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'fontName': fontName,
        'description': description,
        'content': content?.map((MapMarkerContent e) => e.toMap()).toList(),
        'buttons': buttons?.map((MapButton e) => e.toMap()).toList(),
        'constraints': constraints?.toMap(),
        'images': imageUrls,
      };
}

class MapMarkerConstraints {
  final double? width;
  final double? height;
  final double? maxWidth;
  final double? maxHeight;
  final double? minWidth;
  final double? minHeight;

  MapMarkerConstraints({this.width, this.height, this.maxWidth, this.maxHeight, this.minWidth, this.minHeight});

  Map<String, dynamic> toMap() => <String, dynamic>{
        'width': width,
        'height': height,
        'maxWidth': width ?? maxWidth,
        'maxHeight': height ?? maxHeight,
        'minWidth': width ?? minWidth,
        'minHeight': height ?? minHeight,
      };
}
