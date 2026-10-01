import 'package:firebase_auth/firebase_auth.dart';

import '../constants.dart';
import '../models/auth_user.dart';
import 'user_profile_repository.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<void> signIn({required String email, required String password});

  /// Manager bootstrap may register directly. Specialists create a pending request.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth, this._profiles);

  final FirebaseAuth _firebaseAuth;
  final UserProfileRepository _profiles;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  AuthUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _runAuthOperation(
      () => _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await _profiles.ensureProfile(
        userId: user.uid,
        email: user.email ?? email,
      );
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedName = displayName.trim();

    await _runAuthOperation(
      () => _firebaseAuth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      ),
    );

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailure('Не удалось создать аккаунт');
    }

    if (trimmedName.isNotEmpty) {
      await user.updateDisplayName(trimmedName);
    }

    if (isManagerBootstrapEmail(trimmedEmail)) {
      await _profiles.ensureProfile(
        userId: user.uid,
        email: trimmedEmail,
        displayName: trimmedName,
      );
      return;
    }

    await _profiles.submitRegistrationRequest(
      userId: user.uid,
      email: trimmedEmail,
      displayName: trimmedName,
    );
    await _firebaseAuth.signOut();
    throw const RegistrationPendingFailure(
      'Заявка на регистрацию отправлена. Доступ откроется после одобрения руководителем.',
    );
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  Future<void> _runAuthOperation(Future<Object?> Function() operation) async {
    try {
      await operation();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(firebaseAuthErrorMessage(error.code));
    }
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthUser(id: user.uid, email: user.email ?? '');
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class RegistrationPendingFailure implements Exception {
  const RegistrationPendingFailure(this.message);

  final String message;
}

String? validateAuthCredentials({
  required String email,
  required String password,
  required bool isRegistration,
  String displayName = '',
}) {
  if (email.trim().isEmpty || password.isEmpty) {
    return 'Введите email и пароль';
  }
  if (isRegistration && displayName.trim().isEmpty) {
    return 'Укажите ФИО или имя';
  }
  if (isRegistration && password.length < 6) {
    return 'Пароль не короче 6 символов';
  }
  return null;
}

String firebaseAuthErrorMessage(String code) {
  return switch (code) {
    'invalid-email' => 'Некорректный email',
    'user-disabled' => 'Пользователь отключён',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Неверный email или пароль',
    'email-already-in-use' => 'Этот email уже зарегистрирован',
    'weak-password' => 'Слишком слабый пароль (минимум 6 символов)',
    'operation-not-allowed' =>
      'Регистрация по email отключена в Firebase Console',
    'network-request-failed' => 'Нет сети. Проверьте подключение.',
    _ => 'Не удалось выполнить авторизацию',
  };
}
