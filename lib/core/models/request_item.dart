import '../domain/request_status.dart';

class RequestItem {
  RequestItem({
    required this.id,
    required this.stationNumber,
    required this.type,
    required this.requestType,
    required this.description,
    required this.dateCreated,
    required this.status,
    this.closeComment,
    this.closeDate,
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
    this.updatedBy,
    this.updatedAt,
    this.version = 1,
    this.remoteId,
  });

  final int id;
  final String stationNumber;
  final String type;
  final String requestType;
  final String description;
  final String dateCreated;
  final String status;
  final String? closeComment;
  final String? closeDate;
  final String? assigneeId;
  final String? assigneeName;
  final String? dueDate;
  final String? updatedBy;
  final String? updatedAt;
  final int version;
  final String? remoteId;

  bool get isActive => RequestStatus.isActive(status);

  bool get isCritical => requestType.contains('Срочная');

  String get statusLabel => RequestStatus.label(status);

  factory RequestItem.fromMap(Map<String, Object?> map) => RequestItem(
    id: (map['id'] as num?)?.toInt() ?? 0,
    stationNumber: map['station_number'] as String,
    type: (map['type'] as String?) ?? 'НЗ',
    requestType: map['request_type'] as String,
    description: (map['description'] as String?) ?? '',
    dateCreated: map['date_created'] as String,
    status: (map['status'] as String?) ?? RequestStatus.created,
    closeComment: map['close_comment'] as String?,
    closeDate: map['close_date'] as String?,
    assigneeId: map['assignee_id'] as String?,
    assigneeName: map['assignee_name'] as String?,
    dueDate: map['due_date'] as String?,
    updatedBy: map['updated_by'] as String?,
    updatedAt: map['updated_at'] as String?,
    version: (map['version'] as num?)?.toInt() ?? 1,
    remoteId: map['remote_id'] as String?,
  );
}
