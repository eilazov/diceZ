import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/services/auth_service.dart';

void main() {
  group('AuthFailure.fromCode', () {
    test('treats a dismissed sign-in sheet as a cancellation', () {
      for (final code in ['canceled', 'cancelled', 'popup-closed-by-user']) {
        expect(AuthFailure.fromCode(code).cancelled, isTrue, reason: code);
      }
    });

    test('maps network errors to a connectivity message', () {
      final failure = AuthFailure.fromCode('network-request-failed');
      expect(failure.cancelled, isFalse);
      expect(failure.message, contains('connection'));
    });

    test('maps an account clash to a clear message', () {
      final failure = AuthFailure.fromCode(
        'account-exists-with-different-credential',
      );
      expect(failure.message, contains('different sign-in method'));
    });

    test('falls back to a generic message for unknown codes', () {
      expect(AuthFailure.fromCode('whatever').message, 'Sign-in failed.');
    });
  });
}
