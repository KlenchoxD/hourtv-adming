import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/supabase_config.dart';

void main() {
  group('SupabaseConfig', () {
    test('empty url and key produce unconfigured instance without throwing', () {
      final config = SupabaseConfig.parse(url: '', publishableKey: '');
      expect(config.isConfigured, isFalse);
      expect(config.projectUrl, isEmpty);
      expect(config.publishableKey, isEmpty);
    });

    test('configured requires an https URL and publishable key', () {
      expect(SupabaseConfig.parse(url: '', publishableKey: '').isConfigured, isFalse);
      final config = SupabaseConfig.parse(
        url: 'https://project.supabase.co',
        publishableKey: 'sb_publishable_test',
      );
      expect(config.isConfigured, isTrue);
      expect(config.projectUrl, 'https://project.supabase.co');
      expect(config.publishableKey, 'sb_publishable_test');
    });

    test('secret-looking keys are rejected from the client', () {
      expect(
        () => SupabaseConfig.parse(
          url: 'https://project.supabase.co',
          publishableKey: 'service_role.secret',
        ),
        throwsArgumentError,
      );
      expect(
        () => SupabaseConfig.parse(
          url: 'https://project.supabase.co',
          publishableKey: 'sb_secret_abcdef123456',
        ),
        throwsArgumentError,
      );
    });

    test('non-https scheme or invalid URL throws ArgumentError when not both empty', () {
      expect(
        () => SupabaseConfig.parse(
          url: 'http://project.supabase.co',
          publishableKey: 'sb_publishable_test',
        ),
        throwsArgumentError,
      );
      expect(
        () => SupabaseConfig.parse(
          url: 'not-a-url',
          publishableKey: 'sb_publishable_test',
        ),
        throwsArgumentError,
      );
      expect(
        () => SupabaseConfig.parse(
          url: 'https://project.supabase.co',
          publishableKey: '',
        ),
        throwsArgumentError,
      );
    });

    test('fromEnvironment produces safe defaults or parses environment', () {
      final config = SupabaseConfig.fromEnvironment();
      expect(config, isA<SupabaseConfig>());
    });
  });
}
