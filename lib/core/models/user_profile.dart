import 'app_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String email;
  final String displayName;
  final AppRole role;
  final AccountStatus status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  bool get isApproved => status == AccountStatus.approved;
  bool get isPending => status == AccountStatus.pending;
  bool get canAccessApp => isApproved;
  bool get canManageUsers => isApproved && role.canManageUsers;

  UserProfile copyWith({
    String? displayName,
    AppRole? role,
    AccountStatus? status,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.id,
      'status': status.id,
      'createdAt': createdAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
    };
  }

  factory UserProfile.fromFirestore(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      email: (data['email'] as String?)?.trim() ?? '',
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      role: AppRole.fromId(data['role'] as String?),
      status: AccountStatus.fromId(data['status'] as String?),
      createdAt: _parseDate(data['createdAt']),
      reviewedAt: _parseDate(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
