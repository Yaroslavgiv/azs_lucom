class RequestItem {
  RequestItem({
    required this.id,
    required this.stationNumber,
    required this.type,
    required this.requestType,
    required this.description,
    required this.dateCreated,
    required this.status,
    this.workflowStatus = 'created',
    this.assigneeId,
    this.dueAt,
    this.critical = false,
    this.resultText,
    this.category = '',
    this.authorId,
    this.revision = 0,
  });

  final int id;
  final String stationNumber;
  final String type;
  final String requestType;
  final String description;
  final String dateCreated;
  final String status;
  final String workflowStatus;
  final String? assigneeId;
  final String? dueAt;
  final bool critical;
  final String? resultText;
  final String category;
  final String? authorId;
  final int revision;

  factory RequestItem.fromMap(Map<String, Object?> map) => RequestItem(
    id: map['id'] as int,
    stationNumber: map['station_number'] as String,
    type: map['type'] as String,
    requestType: map['request_type'] as String,
    description: (map['description'] as String?) ?? '',
    dateCreated: map['date_created'] as String,
    status: map['status'] as String,
    workflowStatus: (map['workflow_status'] as String?) ?? 'created',
    assigneeId: map['assignee_id'] as String?,
    dueAt: map['due_at'] as String?,
    critical: (map['critical'] as int? ?? 0) == 1,
    resultText: map['result_text'] as String?,
    category: (map['category'] as String?) ?? '',
    authorId: map['author_id'] as String?,
    revision: (map['revision'] as int?) ?? 0,
  );
}
