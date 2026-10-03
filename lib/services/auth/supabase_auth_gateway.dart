import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../supabase_config.dart';
import 'auth_gateway.dart';
import 'native_google_auth.dart';

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(
    this._client, {
    NativeGoogleAccountSelector? googleAccountSelector,
  }) : _googleAccountSelector =
           googleAccountSelector ??
           GoogleNativeAccountSelector(
             serverClientId: SupabaseConfig.googleWebClientId,
           );

  static const String defaultProjectRef = SupabaseConfig.defaultProjectRef;
  static const String googleOAuthWebCallbackUrl =
      SupabaseConfig.googleOAuthCallbackUrl;
  static const String appRedirectUrl = SupabaseConfig.appRedirectUrl;

  static String get currentAuthRedirectUrl =>
      SupabaseConfig.authRedirectUrl(isWeb: kIsWeb);

  final SupabaseClient _client;
  final NativeGoogleAccountSelector _googleAccountSelector;

  @override
  AuthSessionState get currentState => _mapSession(
    _client.auth.currentSession,
    explicitUser: _client.auth.currentUser,
  );

  @override
  Stream<AuthSessionState> get states => _client.auth.onAuthStateChange.map((
    event,
  ) {
    final state = _mapSession(
      event.session,
      explicitUser: _client.auth.currentUser,
    );
    // El enlace del correo de recuperación abre la app con una sesión
    // temporal: se marca aparte para pedir la contraseña nueva.
    if (event.event == AuthChangeEvent.passwordRecovery && state.user != null) {
      return AuthSessionState(
        AuthSessionPhase.passwordRecovery,
        user: state.user,
      );
    }
    return state;
  });

  @override
  Future<AuthSessionState> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: currentAuthRedirectUrl,
    );
    return _mapSession(response.session, explicitUser: response.user);
  }

  @override
  Future<AuthSessionState> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _mapSession(response.session, explicitUser: response.user);
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      return await NativeGoogleAuthFlow(
        selector: _googleAccountSelector,
        exchangeIdToken: (credential) async {
          await _client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: credential.idToken,
          );
        },
        openBrowserFallback: () => _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: currentAuthRedirectUrl,
        ),
      ).signIn();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('not enabled') ||
          msg.contains('provider') ||
          msg.contains('unsupported') ||
          msg.contains('validation_failed')) {
        throw const GoogleAuthNotConfiguredException();
      }
      rethrow;
    }
  }

  @override
  Future<AuthSessionState> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return _mapSession(response.session, explicitUser: response.user);
    } catch (_) {
      try {
        final userResponse = await _client.auth.getUser();
        return _mapSession(
          _client.auth.currentSession,
          explicitUser: userResponse.user,
        );
      } catch (_) {
        return currentState;
      }
    }
  }

  @override
  Future<void> resendVerification(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: currentAuthRedirectUrl,
    );
  }

  @override
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: currentAuthRedirectUrl,
    );
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AuthSessionState _mapSession(Session? session, {User? explicitUser}) {
    final user = explicitUser ?? session?.user ?? _client.auth.currentUser;
    if (user == null) {
      return const AuthSessionState(AuthSessionPhase.signedOut);
    }
    final isVerified = user.emailConfirmedAt != null;
    final authUser = AuthUser(
      id: user.id,
      email: user.email ?? '',
      emailVerified: isVerified,
      provider: user.appMetadata['provider']?.toString() ?? 'email',
      createdAt: DateTime.tryParse(user.createdAt),
    );
    if (!isVerified) {
      return AuthSessionState(
        AuthSessionPhase.verificationRequired,
        user: authUser,
      );
    }
    return AuthSessionState(AuthSessionPhase.authenticated, user: authUser);
  }
}
