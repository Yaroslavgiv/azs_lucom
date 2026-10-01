class MapMarkerIconModel {
  MapMarkerIconModel({required this.iconUrl, required this.width, required this.height});

  final String iconUrl;
  final double width;
  final double height;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'iconUrl': iconUrl,
        'width': width,
        'height': height,
      };

  String toMapJs() => '{"iconUrl": "$iconUrl", '
      '"height": "$height", '
      '"width": "$width"}';
}
