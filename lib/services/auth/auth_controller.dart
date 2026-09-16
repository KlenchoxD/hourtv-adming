import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_gateway.dart';
import 'auth_telemetry.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.gateway}) {
    _subscription = _gateway.states.listen((state) {
      if (!_isGuest) {
        notifyListeners();
      }
    });
  }

  final AuthGateway gateway;
  AuthGateway get _gateway => gateway;
  StreamSubscription<AuthSessionState>? _subscription;

  bool _isLoading = false;
  bool _isGuest = false;
  String? _errorMessage;
  String? _successMessage;

  bool get isLoading => _isLoading;
  bool get isGuest => _isGuest;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  AuthSessionState get sessionState {
    if (_isGuest) {
      return const AuthSessionState(AuthSessionPhase.guest);
    }
    return _gateway.currentState;
  }

  AuthSessionPhase get currentPhase => sessionState.phase;
  AuthUser? get currentUser => sessionState.user;

  void continueAsGuest() {
    _isGuest = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void exitGuestMode() {
    _isGuest = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (!_isValidEmail(cleanEmail)) {
      _errorMessage = 'Ingresa un correo electrónico válido.';
      notifyListeners();
      return false;
    }
    if (cleanPassword.length < 8) {
      _errorMessage = 'La contraseña debe tener al menos 8 caracteres.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    final sw = Stopwatch()..start();
    try {
      _isGuest = false;
      await _gateway.signIn(email: cleanEmail, password: cleanPassword);
      sw.stop();
      AuthTelemetry.instance.recordNetworkRequest(
        sw.elapsedMilliseconds,
        metadata: {'action': 'signIn', 'success': true},
      );
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      sw.stop();
      AuthTelemetry.instance.recordNetworkRequest(
        sw.elapsedMilliseconds,
        metadata: {'action': 'signIn', 'success': false, 'error_type': e.runtimeType.toString()},
      );
      _errorMessage = _mapAuthError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    final sw = Stopwatch()..start();
    try {
      _isGuest = false;
      final launched = await _gateway.signInWithGoogle();
      sw.stop();
      AuthTelemetry.instance.recordNetworkRequest(
        sw.elapsedMilliseconds,
        metadata: {'action': 'signInWithGoogle', 'success': true},
      );
      _errorMessage = null;
      _setLoading(false);
      return launched;
    } catch (e) {
      sw.stop();
      AuthTelemetry.instance.recordNetworkRequest(
        sw.elapsedMilliseconds,
        metadata: {'action': 'signInWithGoogle', 'success': false, 'error_type': e.runtimeType.toString()},
      );
      if (e is GoogleAuthNotConfiguredException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = _mapAuthError(e);
      }
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (!_isValidEmail(cleanEmail)) {
      _errorMessage = 'Ingresa un correo electrónico válido.';
      notifyListeners();
      return false;
    }
    if (cleanPassword.length < 8) {
      _errorMessage = 'La contraseña debe tener al menos 8 caracteres.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    final sw = Stopwatch()..start();
    try {
      _isGuest = false;
      await _gateway.signUp(email: cleanEmail, password: cleanPassword);
      sw.stop();
      AuthTelemetry.instance.recordNetworkRequest(
        sw.elapsedMilliseconds,
        metadata: {'action': 'signUp', 'success': true},
      );
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      sw.stop();
      AuthTelemetry.instance.recordNetworkRequest(
        sw.elapsedMilliseconds,
        metadata: {'action': 'signUp', 'success': false, 'error_type': e.runtimeType.toString()},
      );
      _errorMessage = _mapAuthError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> refreshSession() async {
    _setLoading(true);
    try {
      await _gateway.refreshSession();
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _mapAuthError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resendVerification([String? email]) async {
    final targetEmail = email?.trim() ?? currentUser?.email ?? '';
    if (targetEmail.isEmpty || !_isValidEmail(targetEmail)) {
      _errorMessage = 'Ingresa un correo electrónico válido para reenviar.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      await _gateway.resendVerification(targetEmail);
      _successMessage = 'Correo de verificación reenviado con éxito.';
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _mapAuthError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    final cleanEmail = email.trim();
    if (!_isValidEmail(cleanEmail)) {
      _errorMessage = 'Ingresa un correo electrónico válido.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      await _gateway.resetPassword(cleanEmail);
      _successMessage = 'Se envió un enlace para restablecer tu contraseña.';
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _mapAuthError(e);
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _gateway.signOut();
    } finally {
      _isGuest = false;
      _errorMessage = null;
      _successMessage = null;
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.') && email.indexOf('@') < email.lastIndexOf('.');
  }

  String _mapAuthError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_grant') ||
        msg.contains('user not found')) {
      return 'Credenciales incorrectas o usuario no registrado.';
    }
    if (msg.contains('user already registered') || msg.contains('already exists')) {
      return 'Ya existe una cuenta con este correo electrónico.';
    }
    if (msg.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Demasiados intentos. Espera unos momentos antes de reintentar.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Error de conexión. Verifica tu conexión a internet.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Debes confirmar tu correo electrónico antes de entrar.';
    }
    if (msg.contains('not enabled') ||
        msg.contains('unsupported') ||
        msg.contains('provider') ||
        msg.contains('google')) {
      return 'El inicio de sesión con Google aún no está configurado en el servidor.';
    }
    return 'No se pudo completar la operación. Inténtalo de nuevo más tarde.';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
