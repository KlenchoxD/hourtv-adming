import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_auth_page.dart';
import 'package:streamtv/services/auth/auth_controller.dart';
import 'package:streamtv/services/auth/auth_gateway.dart';
import 'package:streamtv/services/auth/auth_telemetry.dart';

class _FakeTelemetryAuthGateway implements AuthGateway {
  final _controller = StreamController<AuthSessionState>.broadcast();
  final _current = const AuthSessionState(AuthSessionPhase.signedOut);

  @override
  AuthSessionState get currentState => _current;

  @override
  Stream<AuthSessionState> get states => _controller.stream;

  @override
  Future<bool> signInWithGoogle() async => true;

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
    _controller.close();
  }
}

void main() {
  setUp(() {
    AuthTelemetry.instance.clearForTesting();
  });

  tearDown(() {
    AuthTelemetry.instance.clearForTesting();
  });

  group('Auth Telemetry & Strict PII Sanitization Tests', () {
    test('Sanitización estricta elimina correos, contraseñas, tokens, parámetros de URL y claves', () {
      final dirtyMetadata = <String, dynamic>{
        'action': 'login_attempt',
        'success': false,
        'email': 'usuario.secreto@dominio.com',
        'user_email': 'test@hourtv.app',
        'password': 'SuperPassword123!',
        'user_pass': 'SecretP@ss!',
        'auth_token': 'eyJhYmMiOiJkZWYifQ.secret_jwt_token',
        'jwt': 'eyJhGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
        'bearer_token': 'Bearer 9876543210abcdef',
        'service_role_key': 'sb_secret_super_admin_key_here',
        'api_key': 'secret_publishable_or_anon_key',
        'url_with_params': 'https://auth.supabase.co/v1/verify?token=123456&email=secret@test.com#hash=abc',
        'clean_endpoint': 'https://auth.supabase.co/v1/verify',
        'nested_data': {
          'safe_flag': true,
          'user_password': 'NestedPassword99!',
          'raw_email': 'nested@test.com',
        },
      };

      final clean = AuthTelemetry.sanitizeMetadata(dirtyMetadata);

      // Verificaciones de claves eliminadas
      expect(clean.containsKey('email'), isFalse);
      expect(clean.containsKey('user_email'), isFalse);
      expect(clean.containsKey('password'), isFalse);
      expect(clean.containsKey('user_pass'), isFalse);
      expect(clean.containsKey('auth_token'), isFalse);
      expect(clean.containsKey('jwt'), isFalse);
      expect(clean.containsKey('bearer_token'), isFalse);
      expect(clean.containsKey('service_role_key'), isFalse);
      expect(clean.containsKey('api_key'), isFalse);

      // Campos seguros conservados
      expect(clean['action'], equals('login_attempt'));
      expect(clean['success'], equals(false));

      // URLs con parámetros son totalmente descartadas
      expect(clean.containsKey('url_with_params'), isFalse);

      // URLs limpias sin parámetros son conservadas
      expect(clean.containsKey('clean_endpoint'), isTrue);
      expect(clean['clean_endpoint'], equals('https://auth.supabase.co/v1/verify'));

      // Datos anidados sanitizados recursivamente
      final nested = clean['nested_data'] as Map<String, dynamic>;
      expect(nested['safe_flag'], isTrue);
      expect(nested.containsKey('user_password'), isFalse);
      expect(nested.containsKey('raw_email'), isFalse);

      // Conversión a cadena de texto jamás expone datos sensibles
      final textOutput = clean.toString().toLowerCase();
      expect(textOutput.contains('usuario.secreto'), isFalse);
      expect(textOutput.contains('superpassword'), isFalse);
      expect(textOutput.contains('secret_jwt'), isFalse);
      expect(textOutput.contains('sb_secret'), isFalse);
    });

    test('Registra métricas auth_network_request_ms durante operaciones en AuthController', () async {
      final gateway = _FakeTelemetryAuthGateway();
      final controller = AuthController(gateway: gateway);

      await controller.signIn(email: 'test@example.com', password: 'ValidPassword123');
      await controller.signUp(email: 'test@example.com', password: 'ValidPassword123');
      await controller.signInWithGoogle();

      final records = AuthTelemetry.instance.records;
      expect(records.length, greaterThanOrEqualTo(3));

      final netRecords = records.where((r) => r.metricName == AuthTelemetry.authNetworkRequestMs).toList();
      expect(netRecords.length, equals(3));

      expect(netRecords[0].metadata['action'], equals('signIn'));
      expect(netRecords[0].metadata['success'], equals(true));

      expect(netRecords[1].metadata['action'], equals('signUp'));
      expect(netRecords[1].metadata['success'], equals(true));

      expect(netRecords[2].metadata['action'], equals('signInWithGoogle'));
      expect(netRecords[2].metadata['success'], equals(true));

      // Confirmar que ningún registro contiene emails o contraseñas
      for (final r in netRecords) {
        final serialized = r.toString().toLowerCase();
        expect(serialized.contains('test@example.com'), isFalse);
        expect(serialized.contains('validpassword'), isFalse);
      }

      controller.dispose();
      gateway.dispose();
    });

    testWidgets('Registra auth_ui_render_ms y auth_keyboard_toggle_ms en HourTvAuthPage', (tester) async {
      final gateway = _FakeTelemetryAuthGateway();
      final controller = AuthController(gateway: gateway);

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvAuthPage(
            controller: controller,
            onContinueAsGuest: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que auth_ui_render_ms fue emitido en el primer frame
      final uiRecords = AuthTelemetry.instance.records
          .where((r) => r.metricName == AuthTelemetry.authUiRenderMs)
          .toList();
      expect(uiRecords.length, equals(1));
      expect(uiRecords.first.durationMs, greaterThanOrEqualTo(0));

      // Pulsar el botón de alternar visibilidad de contraseña
      final toggleButton = find.byKey(const Key('auth_password_toggle_button'));
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Verificar que auth_keyboard_toggle_ms fue emitido
      final toggleRecords = AuthTelemetry.instance.records
          .where((r) => r.metricName == AuthTelemetry.authKeyboardToggleMs)
          .toList();
      expect(toggleRecords.length, equals(1));
      expect(toggleRecords.first.metadata['obscured'], equals(false));

      controller.dispose();
      gateway.dispose();
    });
  });
}
