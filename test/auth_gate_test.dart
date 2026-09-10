import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_auth_gate.dart';
import 'package:streamtv/services/auth/auth_controller.dart';
import 'package:streamtv/services/auth/auth_gateway.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway(this._state);

  factory FakeAuthGateway.signedOut() =>
      FakeAuthGateway(const AuthSessionState(AuthSessionPhase.signedOut));

  factory FakeAuthGateway.verificationRequired(String email) =>
      FakeAuthGateway(AuthSessionState(
        AuthSessionPhase.verificationRequired,
        user: AuthUser(id: 'u-1', email: email, emailVerified: false),
      ));

  factory FakeAuthGateway.authenticated(String email) =>
      FakeAuthGateway(AuthSessionState(
        AuthSessionPhase.authenticated,
        user: AuthUser(id: 'u-1', email: email, emailVerified: true),
      ));

  AuthSessionState _state;
  final StreamController<AuthSessionState> _controller =
      StreamController<AuthSessionState>.broadcast();

  bool refreshWillVerify = false;
  int refreshCallCount = 0;
  int resendCallCount = 0;

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> get states => _controller.stream;

  void emit(AuthSessionState state) {
    _state = state;
    _controller.add(state);
  }

  @override
  Future<AuthSessionState> signIn({
    required String email,
    required String password,
  }) async {
    final newState = AuthSessionState(
      AuthSessionPhase.authenticated,
      user: AuthUser(id: 'u-1', email: email, emailVerified: true),
    );
    emit(newState);
    return newState;
  }

  @override
  Future<AuthSessionState> signUp({
    required String email,
    required String password,
  }) async {
    final newState = AuthSessionState(
      AuthSessionPhase.verificationRequired,
      user: AuthUser(id: 'u-1', email: email, emailVerified: false),
    );
    emit(newState);
    return newState;
  }

  @override
  Future<AuthSessionState> refreshSession() async {
    refreshCallCount++;
    if (refreshWillVerify && _state.user != null) {
      final newState = AuthSessionState(
        AuthSessionPhase.authenticated,
        user: AuthUser(
          id: _state.user!.id,
          email: _state.user!.email,
          emailVerified: true,
        ),
      );
      emit(newState);
      return newState;
    }
    return _state;
  }

  @override
  Future<void> resendVerification(String email) async {
    resendCallCount++;
  }

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> signOut() async {
    final newState = const AuthSessionState(AuthSessionPhase.signedOut);
    emit(newState);
  }
}

Widget testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('HourTvAuthGate', () {
    testWidgets('access screen preserves explicit Guest entry', (tester) async {
      final gateway = FakeAuthGateway.signedOut();
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthGate(
        controller: controller,
        guestChild: const Text('GUEST_APP'),
        authenticatedChild: const Text('CLOUD_PROFILES'),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Continuar como invitado'), findsOneWidget);
      await tester.tap(find.text('Continuar como invitado'));
      await tester.pumpAndSettle();

      expect(find.text('GUEST_APP'), findsOneWidget);
      expect(find.text('CLOUD_PROFILES'), findsNothing);
    });

    testWidgets('unverified email cannot enter cloud profiles', (tester) async {
      final gateway = FakeAuthGateway.verificationRequired('user@example.com');
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthGate(
        controller: controller,
        guestChild: const Text('GUEST_APP'),
        authenticatedChild: const Text('CLOUD_PROFILES'),
      )));
      await tester.pumpAndSettle();

      expect(find.text('VERIFICA TU CORREO'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('CLOUD_PROFILES'), findsNothing);
    });

    testWidgets('authenticated state displays cloud profiles directly', (tester) async {
      final gateway = FakeAuthGateway.authenticated('user@example.com');
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthGate(
        controller: controller,
        guestChild: const Text('GUEST_APP'),
        authenticatedChild: const Text('CLOUD_PROFILES'),
      )));
      await tester.pumpAndSettle();

      expect(find.text('CLOUD_PROFILES'), findsOneWidget);
      expect(find.text('GUEST_APP'), findsNothing);
    });

    testWidgets('unverified email user can use guest mode from verify screen', (tester) async {
      final gateway = FakeAuthGateway.verificationRequired('user@example.com');
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthGate(
        controller: controller,
        guestChild: const Text('GUEST_APP'),
        authenticatedChild: const Text('CLOUD_PROFILES'),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Usar modo invitado'), findsOneWidget);
      await tester.tap(find.text('Usar modo invitado'));
      await tester.pumpAndSettle();

      expect(find.text('GUEST_APP'), findsOneWidget);
      expect(find.text('CLOUD_PROFILES'), findsNothing);
    });

    testWidgets('verify email refresh transitions to authenticated child when confirmed', (tester) async {
      final gateway = FakeAuthGateway.verificationRequired('user@example.com');
      gateway.refreshWillVerify = true;
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(testApp(HourTvAuthGate(
        controller: controller,
        guestChild: const Text('GUEST_APP'),
        authenticatedChild: const Text('CLOUD_PROFILES'),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Ya verifiqué mi correo'), findsOneWidget);
      await tester.tap(find.text('Ya verifiqué mi correo'));
      await tester.pumpAndSettle();

      expect(find.text('CLOUD_PROFILES'), findsOneWidget);
    });
  });
}
