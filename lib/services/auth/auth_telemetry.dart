import 'package:flutter/foundation.dart';

/// Registro estructurado de telemetría de autenticación.
@immutable
class AuthTelemetryRecord {
  const AuthTelemetryRecord({
    required this.metricName,
    required this.durationMs,
    required this.metadata,
    required this.timestamp,
  });

  final String metricName;
  final int durationMs;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  @override
  String toString() => 'AuthTelemetryRecord($metricName, ${durationMs}ms, $metadata)';
}

/// Servicio centralizado de instrumentación y telemetría de autenticación con
/// sanitización estricta para prevenir la fuga de contraseñas, correos, tokens y claves.
class AuthTelemetry {
  AuthTelemetry._();
  static final AuthTelemetry instance = AuthTelemetry._();

  static const String authUiRenderMs = 'auth_ui_render_ms';
  static const String authKeyboardToggleMs = 'auth_keyboard_toggle_ms';
  static const String authNetworkRequestMs = 'auth_network_request_ms';

  void Function(AuthTelemetryRecord record)? _listener;
  final List<AuthTelemetryRecord> _records = [];

  List<AuthTelemetryRecord> get records => List.unmodifiable(_records);

  void setListener(void Function(AuthTelemetryRecord record)? listener) {
    _listener = listener;
  }

  void clearForTesting() {
    _records.clear();
    _listener = null;
  }

  /// Sanitiza los metadatos eliminando cualquier información sensible:
  /// correos, contraseñas, tokens de acceso, URLs con parámetros y claves de API.
  static Map<String, dynamic> sanitizeMetadata(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const {};

    final sanitized = <String, dynamic>{};
    final blockedKeyPatterns = [
      'email',
      'mail',
      'password',
      'pass',
      'pwd',
      'token',
      'jwt',
      'bearer',
      'secret',
      'apikey',
      'api_key',
      'service_role',
      'credential',
      'param',
      'query',
    ];

    for (final entry in raw.entries) {
      final keyLower = entry.key.toLowerCase().trim();

      // Bloquear claves prohibidas
      final isBlockedKey = blockedKeyPatterns.any((pattern) => keyLower.contains(pattern));
      if (isBlockedKey) {
        continue;
      }

      final value = entry.value;
      if (value is String) {
        final valLower = value.toLowerCase();
        // Bloquear direcciones de correo en el valor
        if (value.contains('@')) {
          continue;
        }
        // Bloquear URLs que contengan parámetros de consulta o fragmentos
        if ((valLower.startsWith('http://') || valLower.startsWith('https://')) &&
            (value.contains('?') || value.contains('#') || value.contains('&'))) {
          continue;
        }
        // Bloquear cadenas con formato de JWT o tokens Bearer
        if (valLower.startsWith('bearer ') ||
            valLower.startsWith('eyj') ||
            valLower.contains('token') ||
            valLower.contains('secret')) {
          continue;
        }
        sanitized[entry.key] = value;
      } else if (value is num || value is bool) {
        sanitized[entry.key] = value;
      } else if (value is Map<String, dynamic>) {
        sanitized[entry.key] = sanitizeMetadata(value);
      }
    }

    return sanitized;
  }

  /// Registra el tiempo de renderizado de la interfaz de autenticación (`auth_ui_render_ms`).
  void recordUiRender(int durationMs, {Map<String, dynamic>? metadata}) {
    _record(authUiRenderMs, durationMs, metadata);
  }

  /// Registra la latencia del cambio de visibilidad de teclado / contraseña (`auth_keyboard_toggle_ms`).
  void recordKeyboardToggle(int durationMs, {Map<String, dynamic>? metadata}) {
    _record(authKeyboardToggleMs, durationMs, metadata);
  }

  /// Registra la duración de peticiones de red hacia el gateway de autenticación (`auth_network_request_ms`).
  void recordNetworkRequest(int durationMs, {Map<String, dynamic>? metadata}) {
    _record(authNetworkRequestMs, durationMs, metadata);
  }

  void _record(String metricName, int durationMs, Map<String, dynamic>? metadata) {
    final sanitized = sanitizeMetadata(metadata);
    final record = AuthTelemetryRecord(
      metricName: metricName,
      durationMs: durationMs,
      metadata: sanitized,
      timestamp: DateTime.now(),
    );
    _records.add(record);
    _listener?.call(record);
  }
}
