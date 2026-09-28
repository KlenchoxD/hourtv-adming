import 'dart:async';

enum AuthSessionPhase {
  guest,
  signedOut,
  verificationRequired,
  authenticated,

  /// Entró con el enlace de "¿Olvidaste tu contraseña?": debe elegir una
  /// contraseña nueva antes de seguir.
  passwordRecovery,
}

final class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.provider = 'email',
    this.createdAt,
  });

  final String id;
  final String email;
  final bool emailVerified;

  /// Cómo se registró: 'email' o 'google'.
  final String provider;
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          emailVerified == other.emailVerified;

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ emailVerified.hashCode;
}

final class AuthSessionState {
  const AuthSessionState(this.phase, {this.user});

  final AuthSessionPhase phase;
  final AuthUser? user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSessionState &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          user == other.user;

  @override
  int get hashCode => phase.hashCode ^ (user?.hashCode ?? 0);
}

class AuthUnavailableException implements Exception {
  final String message;
  const AuthUnavailableException([this.message = 'Supabase no está configurado.']);
  @override
  String toString() => message;
}

class GoogleAuthNotConfiguredException implements Exception {
  final String message;
  const GoogleAuthNotConfiguredException([
    this.message = 'El inicio de sesión con Google aún no está configurado en el servidor.',
  ]);
  @override
  String toString() => message;
}

abstract interface class AuthGateway {
  AuthSessionState get currentState;
  Stream<AuthSessionState> get states;
  Future<AuthSessionState> signUp({required String email, required String password});
  Future<AuthSessionState> signIn({required String email, required String password});
  Future<bool> signInWithGoogle();
  Future<AuthSessionState> refreshSession();
  Future<void> resendVerification(String email);
  Future<void> resetPassword(String email);
  /// Cambia la contraseña de la sesión activa (o de la recuperación).
  Future<void> updatePassword(String newPassword);
  Future<void> signOut();
}
