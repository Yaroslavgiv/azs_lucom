enum AppRole {
  manager,
  admin,
  specialist;

  String get id => name;

  String get labelRu => switch (this) {
    AppRole.manager => 'Руководитель',
    AppRole.admin => 'Администратор',
    AppRole.specialist => 'Специалист',
  };

  static AppRole fromId(String? value) {
    return AppRole.values.firstWhere(
      (role) => role.id == value,
      orElse: () => AppRole.specialist,
    );
  }

  bool get canManageUsers => this == AppRole.manager || this == AppRole.admin;
}

enum AccountStatus {
  pending,
  approved,
  rejected;

  String get id => name;

  String get labelRu => switch (this) {
    AccountStatus.pending => 'Ожидает одобрения',
    AccountStatus.approved => 'Одобрен',
    AccountStatus.rejected => 'Отклонён',
  };

  static AccountStatus fromId(String? value) {
    return AccountStatus.values.firstWhere(
      (status) => status.id == value,
      orElse: () => AccountStatus.pending,
    );
  }
}
