import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_user.dart';
import '../models/registration_request.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(FirebaseFirestore.instance);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    FirebaseAuth.instance,
    ref.watch(userProfileRepositoryProvider),
  );
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return Stream<UserProfile?>.value(null);
      }
      final profiles = ref.watch(userProfileRepositoryProvider);
      return profiles.watchEnsuredProfile(
        userId: user.id,
        email: user.email,
      );
    },
    loading: () => Stream<UserProfile?>.value(null),
    error: (_, _) => Stream<UserProfile?>.value(null),
  );
});

final pendingRegistrationRequestsProvider =
    StreamProvider<List<RegistrationRequest>>((ref) {
      final profile = ref.watch(currentUserProfileProvider).valueOrNull;
      if (profile == null || !profile.canManageUsers) {
        return Stream.value(const <RegistrationRequest>[]);
      }
      return ref.watch(userProfileRepositoryProvider).watchPendingRequests();
    });

final managedUsersProvider = StreamProvider<List<UserProfile>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  if (profile == null || !profile.canManageUsers) {
    return Stream.value(const <UserProfile>[]);
  }
  return ref.watch(userProfileRepositoryProvider).watchAllUsers();
});
