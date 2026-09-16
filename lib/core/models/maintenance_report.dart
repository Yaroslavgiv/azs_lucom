import 'dart:convert';

import '../domain/maintenance_lifecycle.dart';

class MaintenanceChecklistItem {
  const MaintenanceChecklistItem({
    required this.equipmentId,
    required this.title,
    required this.ok,
    this.comment = '',
  });

  final String equipmentId;
  final String title;
  final bool ok;
  final String comment;

  Map<String, Object?> toMap() => {
    'equipment_id': equipmentId,
    'title': title,
    'ok': ok,
    'comment': comment,
  };

  factory MaintenanceChecklistItem.fromMap(Map<String, Object?> map) {
    return MaintenanceChecklistItem(
      equipmentId: '${map['equipment_id'] ?? ''}',
      title: (map['title'] as String?) ?? '',
      ok: map['ok'] == true || map['ok'] == 1,
      comment: (map['comment'] as String?) ?? '',
    );
  }
}

class MaintenanceRecord {
  MaintenanceRecord({
    required this.stationNumber,
    required this.month,
    required this.status,
    this.dateDone,
    this.toType,
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
    this.comment,
    this.checklist = const [],
    this.photoUrls = const [],
    this.updatedBy,
    this.updatedAt,
    this.submittedAt,
    this.reviewedBy,
    this.reviewComment,
    this.version = 1,
  });

  final String stationNumber;
  final String month;
  final String status;
  final String? dateDone;
  final String? toType;
  final String? assigneeId;
  final String? assigneeName;
  final String? dueDate;
  final String? comment;
  final List<MaintenanceChecklistItem> checklist;
  final List<String> photoUrls;
  final String? updatedBy;
  final String? updatedAt;
  final String? submittedAt;
  final String? reviewedBy;
  final String? reviewComment;
  final int version;

  bool get isAccepted => MaintenanceLifecycle.isAccepted(status);

  String get localPk => '${stationNumber}_$month';

  String get statusLabel => MaintenanceLifecycle.label(status);

  Map<String, Object?> toSqliteMap() => {
    'station_number': stationNumber,
    'month': month,
    'status': status,
    'date_done': dateDone,
    'to_type': toType,
    'assignee_id': assigneeId,
    'assignee_name': assigneeName,
    'due_date': dueDate,
    'comment': comment,
    'report_json': jsonEncode(checklist.map((item) => item.toMap()).toList()),
    'photo_paths': jsonEncode(photoUrls),
    'updated_by': updatedBy,
    'updated_at': updatedAt,
    'submitted_at': submittedAt,
    'reviewed_by': reviewedBy,
    'review_comment': reviewComment,
    'version': version,
  };

  factory MaintenanceRecord.fromMap(Map<String, Object?> map) {
    return MaintenanceRecord(
      stationNumber: map['station_number'] as String,
      month: map['month'] as String,
      status: (map['status'] as String?) ?? MaintenanceLifecycle.planned,
      dateDone: map['date_done'] as String?,
      toType: map['to_type'] as String?,
      assigneeId: map['assignee_id'] as String?,
      assigneeName: map['assignee_name'] as String?,
      dueDate: map['due_date'] as String?,
      comment: map['comment'] as String?,
      checklist: _decodeChecklist(map['report_json']),
      photoUrls: _decodeStringList(map['photo_paths'] ?? map['photo_urls']),
      updatedBy: map['updated_by'] as String?,
      updatedAt: map['updated_at'] as String?,
      submittedAt: map['submitted_at'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewComment: map['review_comment'] as String?,
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }

  static List<MaintenanceChecklistItem> _decodeChecklist(Object? raw) {
    if (raw == null || raw.toString().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                MaintenanceChecklistItem.fromMap(item.cast<String, Object?>()),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<String> _decodeStringList(Object? raw) {
    if (raw == null || raw.toString().isEmpty) return const [];
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }
}
