class AuditEvent {
  const AuditEvent({
    required this.action,
    required this.entity,
    required this.entityId,
    required this.actorId,
    required this.actorName,
    required this.createdAt,
    this.summary = '',
    this.payload = const {},
  });

  final String action;
  final String entity;
  final String entityId;
  final String actorId;
  final String actorName;
  final String createdAt;
  final String summary;
  final Map<String, Object?> payload;

  Map<String, Object?> toMap() => {
    'action': action,
    'entity': entity,
    'entity_id': entityId,
    'actor_id': actorId,
    'actor_name': actorName,
    'created_at': createdAt,
    'summary': summary,
    'payload': payload,
  };

  factory AuditEvent.fromMap(Map<String, Object?> map) {
    final rawPayload = map['payload'];
    return AuditEvent(
      action: (map['action'] as String?) ?? '',
      entity: (map['entity'] as String?) ?? '',
      entityId: (map['entity_id'] as String?) ?? '',
      actorId: (map['actor_id'] as String?) ?? '',
      actorName: (map['actor_name'] as String?) ?? '',
      createdAt: (map['created_at'] as String?) ?? '',
      summary: (map['summary'] as String?) ?? '',
      payload: rawPayload is Map
          ? rawPayload.cast<String, Object?>()
          : const {},
    );
  }
}

abstract final class AuditAction {
  static const assignRequest = 'assign_request';
  static const submitMaintenance = 'submit_maintenance';
  static const acceptMaintenance = 'accept_maintenance';
  static const returnMaintenance = 'return_maintenance';
  static const updateCatalog = 'update_catalog';
  static const createUser = 'create_user';
}
