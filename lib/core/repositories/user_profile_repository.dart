import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants.dart';
import '../models/app_role.dart';
import '../models/registration_request.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Emulator / slow GMS often stalls Firestore; keep UI responsive.
  static const Duration firestoreTimeout = Duration(seconds: 6);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('registration_requests');

  /// Ensures a profile exists, then listens for remote updates.
  /// Always emits at least one value (offline fallback if needed).
  Stream<UserProfile?> watchEnsuredProfile({
    required String userId,
    required String email,
    String displayName = '',
  }) async* {
    final ensured = await ensureProfile(
      userId: userId,
      email: email,
      displayName: displayName,
    );
    yield ensured;

    yield* _users
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) return null;
          return UserProfile.fromFirestore(snapshot.id, data);
        })
        .where((profile) => profile != null)
        .handleError((_, _) {});
  }

  Stream<UserProfile?> watchProfile(String userId) {
    return _users.doc(userId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return UserProfile.fromFirestore(snapshot.id, data);
    });
  }

  Future<UserProfile?> getProfile(String userId) async {
    try {
      final cached = await _users
          .doc(userId)
          .get(const GetOptions(source: Source.cache));
      final cachedData = cached.data();
      if (cached.exists && cachedData != null) {
        return UserProfile.fromFirestore(cached.id, cachedData);
      }
    } catch (_) {
      // Cache miss / unavailable — fall through to server.
    }

    try {
      final snapshot = await _users.doc(userId).get().timeout(firestoreTimeout);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return UserProfile.fromFirestore(snapshot.id, data);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Creates or upgrades profile. Manager bootstrap email is always approved.
  /// On Firestore timeout/offline — returns a local fallback so the app can open.
  Future<UserProfile> ensureProfile({
    required String userId,
    required String email,
    String displayName = '',
  }) async {
    try {
      return await _ensureProfileRemote(
        userId: userId,
        email: email,
        displayName: displayName,
      );
    } on TimeoutException {
      return offlineFallbackProfile(
        userId: userId,
        email: email,
        displayName: displayName,
      );
    } catch (_) {
      return offlineFallbackProfile(
        userId: userId,
        email: email,
        displayName: displayName,
      );
    }
  }

  Future<UserProfile> _ensureProfileRemote({
    required String userId,
    required String email,
    String displayName = '',
  }) async {
    final existing = await getProfile(userId);
    final normalizedEmail = email.trim();
    final isManager = isManagerBootstrapEmail(normalizedEmail);

    if (existing != null) {
      if (isManager &&
          (existing.role != AppRole.manager ||
              existing.status != AccountStatus.approved)) {
        final upgraded = existing.copyWith(
          role: AppRole.manager,
          status: AccountStatus.approved,
          displayName: existing.displayName.isEmpty
              ? (displayName.isEmpty ? 'Руководитель' : displayName)
              : existing.displayName,
        );
        await _users
            .doc(userId)
            .set(upgraded.toFirestore(), SetOptions(merge: true))
            .timeout(firestoreTimeout);
        return upgraded;
      }
      return existing;
    }

    final profile = UserProfile(
      id: userId,
      email: normalizedEmail,
      displayName: displayName.trim().isEmpty
          ? (isManager ? 'Руководитель' : normalizedEmail)
          : displayName.trim(),
      role: isManager ? AppRole.manager : AppRole.specialist,
      status: isManager ? AccountStatus.approved : AccountStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );
    await _users.doc(userId).set(profile.toFirestore()).timeout(firestoreTimeout);
    return profile;
  }

  /// Local profile when Firestore is unreachable (emulator GMS / no network).
  static UserProfile offlineFallbackProfile({
    required String userId,
    required String email,
    String displayName = '',
  }) {
    final normalizedEmail = email.trim();
    final isManager = isManagerBootstrapEmail(normalizedEmail);
    final name = displayName.trim();
    return UserProfile(
      id: userId,
      email: normalizedEmail,
      displayName: name.isEmpty
          ? (isManager ? 'Руководитель' : normalizedEmail)
          : name,
      role: isManager ? AppRole.manager : AppRole.specialist,
      status: isManager ? AccountStatus.approved : AccountStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<void> submitRegistrationRequest({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    final now = DateTime.now().toUtc();
    final profile = UserProfile(
      id: userId,
      email: email.trim(),
      displayName: displayName.trim(),
      role: AppRole.specialist,
      status: AccountStatus.pending,
      createdAt: now,
    );
    final request = RegistrationRequest(
      id: userId,
      email: email.trim(),
      displayName: displayName.trim(),
      status: AccountStatus.pending,
      requestedRole: AppRole.specialist,
      createdAt: now,
    );
    final batch = _firestore.batch();
    batch.set(_users.doc(userId), profile.toFirestore());
    batch.set(_requests.doc(userId), request.toFirestore());
    await batch.commit().timeout(firestoreTimeout);
  }

  Stream<List<RegistrationRequest>> watchPendingRequests() {
    return _requests
        .where('status', isEqualTo: AccountStatus.pending.id)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => RegistrationRequest.fromFirestore(doc.id, doc.data()))
              .toList();
          items.sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return items;
        });
  }

  Stream<List<UserProfile>> watchAllUsers() {
    return _users.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc.id, doc.data()))
          .toList();
      items.sort((a, b) => a.email.compareTo(b.email));
      return items;
    });
  }

  Future<void> approveRegistration({
    required String userId,
    required AppRole role,
    required String reviewerId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _firestore.batch();
    batch.set(_users.doc(userId), {
      'role': role.id,
      'status': AccountStatus.approved.id,
      'reviewedAt': now,
      'reviewedBy': reviewerId,
    }, SetOptions(merge: true));
    batch.set(_requests.doc(userId), {
      'status': AccountStatus.approved.id,
      'requestedRole': role.id,
      'reviewedAt': now,
      'reviewedBy': reviewerId,
    }, SetOptions(merge: true));
    await batch.commit().timeout(firestoreTimeout);
  }

  Future<void> rejectRegistration({
    required String userId,
    required String reviewerId,
    String? note,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _firestore.batch();
    batch.set(_users.doc(userId), {
      'status': AccountStatus.rejected.id,
      'reviewedAt': now,
      'reviewedBy': reviewerId,
    }, SetOptions(merge: true));
    batch.set(_requests.doc(userId), {
      'status': AccountStatus.rejected.id,
      'reviewedAt': now,
      'reviewedBy': reviewerId,
      'reviewNote': ?note,
    }, SetOptions(merge: true));
    await batch.commit().timeout(firestoreTimeout);
  }

  Future<void> updateUserRole({
    required String userId,
    required AppRole role,
    required String reviewerId,
  }) async {
    await _users.doc(userId).set({
      'role': role.id,
      'status': AccountStatus.approved.id,
      'reviewedAt': DateTime.now().toUtc().toIso8601String(),
      'reviewedBy': reviewerId,
    }, SetOptions(merge: true)).timeout(firestoreTimeout);
  }
}
