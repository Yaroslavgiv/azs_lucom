import 'package:azs_app/core/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateAuthCredentials', () {
    test('rejects empty credentials', () {
      final result = validateAuthCredentials(
        email: ' ',
        password: '',
        isRegistration: false,
      );

      expect(result, 'Введите email и пароль');
    });

    test('rejects a short registration password', () {
      final result = validateAuthCredentials(
        email: 'user@example.com',
        password: '12345',
        isRegistration: true,
      );

      expect(result, 'Пароль не короче 6 символов');
    });

    test('accepts valid sign-in credentials', () {
      final result = validateAuthCredentials(
        email: 'user@example.com',
        password: 'secret',
        isRegistration: false,
      );

      expect(result, isNull);
    });
  });

  group('firebaseAuthErrorMessage', () {
    test('does not reveal whether an account exists', () {
      expect(
        firebaseAuthErrorMessage('user-not-found'),
        firebaseAuthErrorMessage('wrong-password'),
      );
    });

    test('maps network failures to a user-facing message', () {
      expect(
        firebaseAuthErrorMessage('network-request-failed'),
        'Нет сети. Проверьте подключение.',
      );
    });

    test('does not expose unknown Firebase details', () {
      expect(
        firebaseAuthErrorMessage('internal-error-with-sensitive-details'),
        'Не удалось выполнить авторизацию',
      );
    });
  });
}
