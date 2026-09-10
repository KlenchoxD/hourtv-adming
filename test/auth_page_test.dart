import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_auth_page.dart';
import 'package:streamtv/services/auth/auth_controller.dart';
import 'package:streamtv/services/auth/auth_gateway.dart';

class MockAuthGateway implements AuthGateway {
  MockAuthGateway();

  String? lastSignUpEmail;
  String? lastSignUpPassword;
  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastResetEmail;
  bool shouldFail = false;
  String failMessage = 'Error simulado';

  final StreamController<AuthSessionState> _controller =
      StreamController<AuthSessionState>.broadcast();
  AuthSessionState _state =
      const AuthSessionState(AuthSessionPhase.signedOut);

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> get states => _controller.stream;

  @override
  Future<AuthSessionState> signUp({
    required String email,
    required String password,
  }) async {
    lastSignUpEmail = email;
    lastSignUpPassword = password;
    if (shouldFail) throw Exception(failMessage);
    _state = AuthSessionState(
      AuthSessionPhase.verificationRequired,
      user: AuthUser(id: 'u-new', email: email, emailVerified: false),
    );
    _controller.add(_state);
    return _state;
  }

  @override
  Future<AuthSessionState> signIn({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (shouldFail) throw Exception(failMessage);
    _state = AuthSessionState(
      AuthSessionPhase.authenticated,
      user: AuthUser(id: 'u-1', email: email, emailVerified: true),
    );
    _controller.add(_state);
    return _state;
  }

  @override
  Future<AuthSessionState> refreshSession() async => _state;

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> resetPassword(String email) async {
    lastResetEmail = email;
    if (shouldFail) throw Exception(failMessage);
  }

  @override
  Future<void> signOut() async {
    _state = const AuthSessionState(AuthSessionPhase.signedOut);
    _controller.add(_state);
  }
}

Widget testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('HourTvAuthPage', () {
    testWidgets('renders action buttons and options', (tester) async {
      final gateway = MockAuthGateway();
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthPage(
        controller: controller,
        onContinueAsGuest: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('INICIAR SESIÓN'), findsWidgets);
      expect(find.text('CREAR CUENTA'), findsWidgets);
      expect(find.text('Continuar como invitado'), findsOneWidget);
    });

    testWidgets('validates email format and password length in Spanish', (tester) async {
      final gateway = MockAuthGateway();
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthPage(
        controller: controller,
        onContinueAsGuest: () {},
      )));
      await tester.pumpAndSettle();

      // Test invalid email
      final emailFinder = find.byKey(const Key('auth_email_field'));
      final passwordFinder = find.byKey(const Key('auth_password_field'));

      await tester.enterText(emailFinder, 'invalid-email');
      await tester.enterText(passwordFinder, '12345678');
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa un correo electrónico válido.'), findsOneWidget);

      // Test short password
      await tester.enterText(emailFinder, 'valid@example.com');
      await tester.enterText(passwordFinder, '123');
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('La contraseña debe tener al menos 8 caracteres.'), findsOneWidget);
      expect(gateway.lastSignInEmail, isNull);
    });

    testWidgets('submitting valid registration calls gateway signUp', (tester) async {
      final gateway = MockAuthGateway();
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthPage(
        controller: controller,
        onContinueAsGuest: () {},
      )));
      await tester.pumpAndSettle();

      // Switch to Crear Cuenta tab
      await tester.tap(find.byKey(const Key('auth_tab_signup')));
      await tester.pumpAndSettle();

      final emailFinder = find.byKey(const Key('auth_email_field'));
      final passwordFinder = find.byKey(const Key('auth_password_field'));

      await tester.enterText(emailFinder, 'newuser@example.com');
      await tester.enterText(passwordFinder, 'SecurePass123!');
      await tester.pump();

      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(gateway.lastSignUpEmail, 'newuser@example.com');
      expect(gateway.lastSignUpPassword, 'SecurePass123!');
    });

    testWidgets('forgot password sends reset email request', (tester) async {
      final gateway = MockAuthGateway();
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthPage(
        controller: controller,
        onContinueAsGuest: () {},
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('auth_email_field')), 'reset@example.com');
      await tester.pump();

      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      expect(gateway.lastResetEmail, 'reset@example.com');
      expect(find.text('Se envió un enlace para restablecer tu contraseña.'), findsOneWidget);
    });
  });
}
