import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../domain/user_role.dart';
import '../models/user_profile.dart';
import '../services/sync_change_publisher.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore, AppDatabase? cache})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _cache = cache;

  final FirebaseFirestore _firestore;
  final AppDatabase? _cache;

  Future<UserProfile?> getById(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(SyncEntity.users)
          .doc(uid)
          .get();
      if (snapshot.exists) {
        final profile = UserProfile.fromMap(uid, snapshot.data() ?? {});
        await _saveCache(profile);
        return profile;
      }
    } catch (_) {
      final cached = await _readCache(uid);
      if (cached != null) return cached;
    }
    return _readCache(uid);
  }

  Future<List<UserProfile>> listAll() async {
    try {
      final snapshot = await _firestore.collection(SyncEntity.users).get();
      final profiles = snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
          .toList();
      for (final profile in profiles) {
        await _saveCache(profile);
      }
      return profiles;
    } catch (_) {
      return _listCache();
    }
  }

  Future<List<UserProfile>> listSpecialists() async {
    final all = await listAll();
    return all
        .where(
          (profile) => profile.role == UserRole.specialist && !profile.disabled,
        )
        .toList();
  }

  Future<void> upsert(UserProfile profile) async {
    await _firestore.collection(SyncEntity.users).doc(profile.id).set({
      ...profile.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _saveCache(profile);
  }

  Future<void> _saveCache(UserProfile profile) async {
    final cache = _cache;
    if (cache == null) return;
    await cache.db.insert('users_cache', {
      'id': profile.id,
      'email': profile.email,
      'display_name': profile.displayName,
      'role': profile.role.wireValue,
      'regions': profile.regions.join(','),
      'disabled': profile.disabled ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserProfile?> _readCache(String uid) async {
    final cache = _cache;
    if (cache == null) return null;
    final rows = await cache.db.query(
      'users_cache',
      where: 'id = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(uid, rows.first);
  }

  Future<List<UserProfile>> _listCache() async {
    final cache = _cache;
    if (cache == null) return const [];
    final rows = await cache.db.query('users_cache', orderBy: 'display_name');
    return rows
        .map((row) => UserProfile.fromMap(row['id'] as String, row))
        .toList();
  }
}
