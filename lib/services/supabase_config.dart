final class SupabaseConfig {
  const SupabaseConfig._(this.projectUrl, this.publishableKey);

  final String projectUrl;
  final String publishableKey;
  bool get isConfigured => projectUrl.isNotEmpty && publishableKey.isNotEmpty;

  factory SupabaseConfig.fromEnvironment() => SupabaseConfig.parse(
        url: const String.fromEnvironment('SUPABASE_URL'),
        publishableKey:
            const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
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
    if (url.trim().isEmpty && key.isEmpty) return const SupabaseConfig._('', '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || key.isEmpty) {
      throw ArgumentError('Configuración de Supabase incompleta.');
    }
    return SupabaseConfig._(uri.toString(), key);
  }
}
