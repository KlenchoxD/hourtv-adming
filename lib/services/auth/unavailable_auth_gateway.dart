import 'dart:async';
import 'auth_gateway.dart';

class UnavailableAuthGateway implements AuthGateway {
  UnavailableAuthGateway({AuthSessionState? initialState})
      : _state = initialState ?? const AuthSessionState(AuthSessionPhase.signedOut);

  final AuthSessionState _state;
  final StreamController<AuthSessionState> _controller =
      StreamController<AuthSessionState>.broadcast();

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> get states => _controller.stream;

  @override
  Future<AuthSessionState> signIn({
    required String email,
    required String password,
  }) async {
    throw const AuthUnavailableException();
  }

  @override
  Future<AuthSessionState> signUp({
    required String email,
    required String password,
  }) async {
    throw const AuthUnavailableException();
  }

  @override
  Future<AuthSessionState> refreshSession() async {
    throw const AuthUnavailableException();
  }

  @override
  Future<void> resendVerification(String email) async {
    throw const AuthUnavailableException();
  }

  @override
  Future<void> resetPassword(String email) async {
    throw const AuthUnavailableException();
  }

  @override
  Future<void> signOut() async {
    // No-op for unavailable gateway
  }
}
