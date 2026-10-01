import 'app_role.dart';

class RegistrationRequest {
  const RegistrationRequest({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    required this.requestedRole,
    this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNote,
  });

  final String id;
  final String email;
  final String displayName;
  final AccountStatus status;
  final AppRole requestedRole;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNote;

  bool get isPending => status == AccountStatus.pending;

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'status': status.id,
      'requestedRole': requestedRole.id,
      'createdAt': createdAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewNote': reviewNote,
    };
  }

  factory RegistrationRequest.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return RegistrationRequest(
      id: id,
      email: (data['email'] as String?)?.trim() ?? '',
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      status: AccountStatus.fromId(data['status'] as String?),
      requestedRole: AppRole.fromId(
        (data['requestedRole'] as String?) ?? AppRole.specialist.id,
      ),
      createdAt: _parseDate(data['createdAt']),
      reviewedAt: _parseDate(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
      reviewNote: data['reviewNote'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
