class RequestItem {
  RequestItem({
    required this.id,
    required this.stationNumber,
    required this.type,
    required this.requestType,
    required this.description,
    required this.dateCreated,
    required this.status,
  });

  final int id;
  final String stationNumber;
  final String type;
  final String requestType;
  final String description;
  final String dateCreated;
  final String status;

  factory RequestItem.fromMap(Map<String, Object?> map) => RequestItem(
    id: map['id'] as int,
    stationNumber: map['station_number'] as String,
    type: map['type'] as String,
    requestType: map['request_type'] as String,
    description: (map['description'] as String?) ?? '',
    dateCreated: map['date_created'] as String,
    status: map['status'] as String,
  );
}
