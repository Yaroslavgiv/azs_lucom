class MapMarkerContent {
  MapMarkerContent({required this.title, this.description, this.hexColor = '#000000', this.fontName, this.fontNameDescription});

  String title;
  String? description;
  String? hexColor;
  String? fontName;
  String? fontNameDescription;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'description': description,
        'hexColor': hexColor,
        'fontName': fontName,
        'fontNameDescription': fontNameDescription,
      };
}
