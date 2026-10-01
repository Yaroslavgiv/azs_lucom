import 'dart:ui';

import 'package:ntk_map_view/src/modules/color_to_hex.dart';

class MapButton {
  final String title;
  final Function onTap;
  int? height;
  int? width;
  MapButtonDecoration? decoration;
  String? id;

  MapButton({
    required this.title,
    required this.onTap,
    this.height,
    this.width,
    this.decoration
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': title,
        'id': id,
        'height': height,
        'width': width,
        'borderRadius': decoration?.borderRadius,
        'colorHex': decoration?.backgroundColor?.toHex(),
        'textColorHex': decoration?.textColor?.toHex(),
      };
}

class MapButtonDecoration{
  int? borderRadius;
  Color? backgroundColor;
  Color? textColor;

  MapButtonDecoration({this.borderRadius, this.backgroundColor, this.textColor});
}