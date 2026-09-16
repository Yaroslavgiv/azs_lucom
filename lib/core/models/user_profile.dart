import '../constants.dart';
import '../domain/user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.regions,
    this.disabled = false,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final List<String> regions;
  final bool disabled;

  String get shortName {
    final name = displayName.trim();
    if (name.isNotEmpty) return name;
    return email;
  }

  bool allowsRegion(String region) {
    if (role == UserRole.admin) return true;
    if (regions.isEmpty) return true;
    return regions.contains(region);
  }

  factory UserProfile.fallback({required String id, required String email}) {
    return UserProfile(
      id: id,
      email: email,
      displayName: email,
      role: UserRole.specialist,
      regions: const [regionSpb, regionNovgorod],
    );
  }

  factory UserProfile.fromMap(String id, Map<String, Object?> map) {
    final rawRegions = map['regions'];
    final regions = <String>[];
    if (rawRegions is List) {
      for (final item in rawRegions) {
        if (item != null && item.toString().isNotEmpty) {
          regions.add(item.toString());
        }
      }
    } else if (rawRegions is String && rawRegions.isNotEmpty) {
      regions.addAll(
        rawRegions
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    }
    return UserProfile(
      id: id,
      email: (map['email'] as String?) ?? '',
      displayName:
          (map['display_name'] as String?) ??
          (map['displayName'] as String?) ??
          '',
      role: UserRole.fromWire(map['role'] as String?),
      regions: regions.isEmpty ? const [regionSpb, regionNovgorod] : regions,
      disabled: map['disabled'] == true || map['disabled'] == 1,
    );
  }

  Map<String, Object?> toMap() => {
    'email': email,
    'display_name': displayName,
    'role': role.wireValue,
    'regions': regions,
    'disabled': disabled,
  };
}
