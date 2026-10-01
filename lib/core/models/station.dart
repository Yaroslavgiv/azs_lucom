class Station {
  Station({
    required this.number,
    required this.name,
    required this.address,
    required this.region,
    this.lat,
    this.lon,
    this.geocodeStatus = 0,
    this.managementId,
    this.departmentId,
    this.crewId,
    this.active = true,
    this.createdBy,
    this.createdAt,
    this.inputMethod,
  });

  final String number;
  final String name;
  final String address;
  final String region;
  final double? lat;
  final double? lon;
  final int geocodeStatus;
  final String? managementId;
  final String? departmentId;
  final String? crewId;
  final bool active;
  final String? createdBy;
  final String? createdAt;
  final String? inputMethod;

  bool get hasCoordinates => lat != null && lon != null;

  String get displayTitle =>
      name.isNotEmpty ? name : (address.isNotEmpty ? address : 'АЗС $number');

  factory Station.fromMap(Map<String, Object?> map) => Station(
    number: map['number'] as String,
    name: (map['name'] as String?) ?? '',
    address: (map['address'] as String?) ?? '',
    region: map['region'] as String,
    lat: (map['lat'] as num?)?.toDouble(),
    lon: (map['lon'] as num?)?.toDouble(),
    geocodeStatus: (map['geocode_status'] as int?) ?? 0,
    managementId: map['management_id'] as String?,
    departmentId: map['department_id'] as String?,
    crewId: map['crew_id'] as String?,
    active: (map['active'] as int? ?? 1) == 1,
    createdBy: map['created_by'] as String?,
    createdAt: map['created_at'] as String?,
    inputMethod: map['input_method'] as String?,
  );

  Map<String, Object?> toMap() => {
    'number': number,
    'name': name,
    'address': address,
    'region': region,
    'lat': lat,
    'lon': lon,
    'geocode_status': geocodeStatus,
    'management_id': managementId,
    'department_id': departmentId,
    'crew_id': crewId,
    'active': active ? 1 : 0,
    'created_by': createdBy,
    'created_at': createdAt,
    'input_method': inputMethod,
  };
}
