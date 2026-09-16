/// Роли первой версии системы обслуживания АЗС.
enum UserRole {
  specialist,
  manager,
  admin;

  static const wireSpecialist = 'specialist';
  static const wireManager = 'manager';
  static const wireAdmin = 'admin';

  String get wireValue => name;

  String get label => switch (this) {
    UserRole.specialist => 'Специалист',
    UserRole.manager => 'Руководитель',
    UserRole.admin => 'Администратор',
  };

  bool get canAssignWork => this == UserRole.manager || this == UserRole.admin;

  bool get canAcceptMaintenance =>
      this == UserRole.manager || this == UserRole.admin;

  bool get canManageUsers => this == UserRole.admin;

  bool get canManageCatalogs =>
      this == UserRole.manager || this == UserRole.admin;

  static UserRole fromWire(String? value) {
    return switch (value) {
      wireAdmin => UserRole.admin,
      wireManager => UserRole.manager,
      _ => UserRole.specialist,
    };
  }
}
