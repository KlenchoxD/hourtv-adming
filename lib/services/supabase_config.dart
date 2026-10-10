final class SupabaseConfig {
  const SupabaseConfig._(this.projectUrl, this.publishableKey);

  final String projectUrl;
  final String publishableKey;
  bool get isConfigured => projectUrl.isNotEmpty && publishableKey.isNotEmpty;

  /// Identificador de proyecto canónico de Supabase
  static const String defaultProjectRef = 'pzbehpbtuiyrerrzgkcd';

  /// URL base canónica del proyecto Supabase
  static const String defaultProjectUrl =
      'https://$defaultProjectRef.supabase.co';

  /// Clave publica del cliente. La proteccion de datos depende de RLS;
  /// nunca colocar aqui una clave secret/service_role.
  static const String defaultPublishableKey =
      'sb_publishable_91lPSQVU5LQy4i2ManHrug_7JvJa1Ra';

  /// URL de callback de Google hacia Supabase (para configuración en Google Cloud Console)
  static const String googleOAuthCallbackUrl =
      'https://$defaultProjectRef.supabase.co/auth/v1/callback';

  /// URL de redirección desde Supabase hacia la aplicación móvil (Deep link)
  static const String appRedirectUrl = 'hourtv://auth-callback';

  /// Web vuelve al origen de acceso; las aplicaciones conservan el deep link.
  static String authRedirectUrl({required bool isWeb, Uri? currentUri}) {
    if (!isWeb) return appRedirectUrl;
    final uri = currentUri ?? Uri.base;
    if ((uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
      throw ArgumentError.value(uri, 'currentUri', 'Origen web inválido.');
    }
    return '${uri.origin}/';
  }

  /// Client ID OAuth de tipo Web usado para validar tokens nativos de Google.
  /// Se inyecta en compilación y nunca debe incluir el client secret.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  factory SupabaseConfig.fromEnvironment() => SupabaseConfig.parse(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: defaultProjectUrl,
    ),
    publishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: defaultPublishableKey,
    ),
  );

  factory SupabaseConfig.parse({
    required String url,
    required String publishableKey,
  }) {
    final uri = Uri.tryParse(url.trim());
    final key = publishableKey.trim();
    if (key.toLowerCase().contains('service_role') ||
        key.toLowerCase().startsWith('sb_secret_')) {
      throw ArgumentError('La APK solo acepta una clave publicable.');
    }
    if (url.trim().isEmpty && key.isEmpty) {
      return const SupabaseConfig._('', '');
    }
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        key.isEmpty) {
      throw ArgumentError('Configuración de Supabase incompleta.');
    }
    return SupabaseConfig._(uri.toString(), key);
  }
}
