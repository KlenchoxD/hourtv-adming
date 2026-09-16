import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_auth_page.dart';
import 'package:streamtv/services/auth/auth_controller.dart';
import 'package:streamtv/services/auth/auth_gateway.dart';

class MockAuthGateway implements AuthGateway {
  final _stateController = StreamController<AuthSessionState>.broadcast();
  final AuthSessionState _current = const AuthSessionState(AuthSessionPhase.signedOut);
  bool simulateGoogleUnconfigured = false;

  @override
  AuthSessionState get currentState => _current;

  @override
  Stream<AuthSessionState> get states => _stateController.stream;

  @override
  Future<bool> signInWithGoogle() async {
    if (simulateGoogleUnconfigured) {
      throw const GoogleAuthNotConfiguredException();
    }
    return true;
  }

  @override
  Future<AuthSessionState> signIn({required String email, required String password}) async => _current;

  @override
  Future<AuthSessionState> signUp({required String email, required String password}) async => _current;

  @override
  Future<AuthSessionState> refreshSession() async => _current;

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> signOut() async {}

  void dispose() {
    _stateController.close();
  }
}

void main() {
  late MockAuthGateway gateway;
  late AuthController controller;

  setUp(() {
    gateway = MockAuthGateway();
    controller = AuthController(gateway: gateway);
  });

  tearDown(() {
    controller.dispose();
    gateway.dispose();
  });

  group('Google OAuth and Instrumented Auth UI', () {
    test('signInWithGoogle exposes user-friendly message when provider is unconfigured', () async {
      gateway.simulateGoogleUnconfigured = true;

      final result = await controller.signInWithGoogle();

      expect(result, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(
        controller.errorMessage,
        contains('El inicio de sesión con Google aún no está configurado en el servidor.'),
      );
    });

    testWidgets('HourTvAuthPage renders Google button, AutofillGroup, and password visibility toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HourTvAuthPage(
            controller: controller,
            onContinueAsGuest: () {},
          ),
        ),
      );

      // Verify AutofillGroup is present
      expect(find.byType(AutofillGroup), findsOneWidget);

      // Verify Google login button is present
      final googleBtn = find.text('Continuar con Google');
      expect(googleBtn, findsOneWidget);

      // Verify password visibility toggle is present
      final toggleFinder = find.byKey(const Key('auth_password_toggle_button'));
      expect(toggleFinder, findsOneWidget);

      // Initial password field is obscured
      final passwordField = tester.widget<TextField>(find.byKey(const Key('auth_password_field')));
      expect(passwordField.obscureText, isTrue);

      // Tap toggle to reveal password
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      final revealedField = tester.widget<TextField>(find.byKey(const Key('auth_password_field')));
      expect(revealedField.obscureText, isFalse);

      // Tap Google button with unconfigured simulation
      gateway.simulateGoogleUnconfigured = true;
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      // Verify error message is shown in UI
      expect(find.textContaining('El inicio de sesión con Google aún no está configurado'), findsOneWidget);
    });
  });
}
