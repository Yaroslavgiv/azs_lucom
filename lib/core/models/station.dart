class Station {
  Station({
    required this.number,
    required this.name,
    required this.address,
    required this.region,
    this.lat,
    this.lon,
    this.geocodeStatus = 0,
  });

  final String number;
  final String name;
  final String address;
  final String region;
  final double? lat;
  final double? lon;
  final int geocodeStatus;

  bool get hasCoordinates => lat != null && lon != null;

  String get displayTitle => name.isNotEmpty ? name : (address.isNotEmpty ? address : 'АЗС $number');

  factory Station.fromMap(Map<String, Object?> map) => Station(
        number: map['number'] as String,
        name: (map['name'] as String?) ?? '',
        address: (map['address'] as String?) ?? '',
        region: map['region'] as String,
        lat: map['lat'] as double?,
        lon: map['lon'] as double?,
        geocodeStatus: (map['geocode_status'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => {
        'number': number,
        'name': name,
        'address': address,
        'region': region,
        'lat': lat,
        'lon': lon,
        'geocode_status': geocodeStatus,
      };
}
