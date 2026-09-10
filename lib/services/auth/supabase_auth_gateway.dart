import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'auth_gateway.dart';

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  AuthSessionState get currentState => _mapSession(
        _client.auth.currentSession,
        explicitUser: _client.auth.currentUser,
      );

  @override
  Stream<AuthSessionState> get states =>
      _client.auth.onAuthStateChange.map((event) => _mapSession(
            event.session,
            explicitUser: _client.auth.currentUser,
          ));

  @override
  Future<AuthSessionState> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'hourtv://auth-callback',
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
      emailRedirectTo: 'hourtv://auth-callback',
    );
  }

  @override
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'hourtv://auth-callback',
    );
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
    );
    if (!isVerified) {
      return AuthSessionState(
        AuthSessionPhase.verificationRequired,
        user: authUser,
      );
    }
    return AuthSessionState(
      AuthSessionPhase.authenticated,
      user: authUser,
    );
  }
}
