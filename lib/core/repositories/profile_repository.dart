import 'package:azs_domain/azs_domain.dart';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class ProfileRepository {
  const ProfileRepository(this._db);

  final AppDatabase _db;

  Future<AccessSubject?> find(String userId) async {
    final rows = await _db.db.query(
      'user_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _subject(rows.first);
  }

  Future<void> upsert({
    required AccessSubject subject,
    String displayName = '',
    String contact = '',
    String? fcmToken,
  }) async {
    await _db.db.insert('user_profiles', {
      'user_id': subject.userId,
      'display_name': displayName,
      'role': appRoleCode(subject.role),
      'manager_scope': managerScopeCode(subject.effectiveScope),
      'management_id': subject.managementId,
      'department_id': subject.departmentId,
      'crew_id': subject.crewId,
      'active': subject.active ? 1 : 0,
      'contact': contact,
      'fcm_token': fcmToken,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AccessSubject>> leadersInScope(OrgStation station) async {
    final rows = await _db.db.query('user_profiles', where: 'active = 1');
    return rows.map(_subject).where((subject) {
      if (!subject.isLeader) return false;
      return canReadStation(subject, station);
    }).toList();
  }

  AccessSubject _subject(Map<String, Object?> row) {
    return subjectFromCodes(
      userId: row['user_id'] as String,
      roleCode: row['role'] as String?,
      scopeCode: row['manager_scope'] as String?,
      managementId: row['management_id'] as String?,
      departmentId: row['department_id'] as String?,
      crewId: row['crew_id'] as String?,
      active: (row['active'] as int? ?? 1) == 1,
    );
  }
}
