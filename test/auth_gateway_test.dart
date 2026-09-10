import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/auth/auth_gateway.dart';
import 'package:streamtv/services/auth/unavailable_auth_gateway.dart';

void main() {
  group('UnavailableAuthGateway', () {
    test('unavailable gateway never accepts cloud login', () async {
      final gateway = UnavailableAuthGateway();
      await expectLater(
        gateway.signIn(email: 'user@example.com', password: 'Password123!'),
        throwsA(isA<AuthUnavailableException>()),
      );
      await expectLater(
        gateway.signUp(email: 'user@example.com', password: 'Password123!'),
        throwsA(isA<AuthUnavailableException>()),
      );
      await expectLater(
        gateway.refreshSession(),
        throwsA(isA<AuthUnavailableException>()),
      );
      await expectLater(
        gateway.resendVerification('user@example.com'),
        throwsA(isA<AuthUnavailableException>()),
      );
      await expectLater(
        gateway.resetPassword('user@example.com'),
        throwsA(isA<AuthUnavailableException>()),
      );
      expect(gateway.currentState.phase, AuthSessionPhase.signedOut);
    });

    test('unavailable gateway signOut completes quietly', () async {
      final gateway = UnavailableAuthGateway();
      await expectLater(gateway.signOut(), completes);
      expect(gateway.currentState.phase, AuthSessionPhase.signedOut);
    });
  });
}
