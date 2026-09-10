import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/auth/unavailable_auth_gateway.dart';
import 'package:streamtv/services/supabase_bootstrap.dart';
import 'package:streamtv/services/supabase_config.dart';

void main() {
  group('SupabaseBootstrap', () {
    test('missing config keeps Guest mode available without initializing Supabase', () async {
      final bootstrap = SupabaseBootstrap.forTest();
      await bootstrap.initialize(SupabaseConfig.parse(url: '', publishableKey: ''));
      expect(bootstrap.isAvailable, isFalse);
      expect(bootstrap.authGateway, isA<UnavailableAuthGateway>());
    });

    test('configured bootstrap with custom gateway uses it', () async {
      final customGateway = UnavailableAuthGateway();
      final bootstrap = SupabaseBootstrap.forTest(authGateway: customGateway);
      await bootstrap.initialize(SupabaseConfig.parse(
        url: 'https://project.supabase.co',
        publishableKey: 'sb_publishable_test',
      ));
      expect(bootstrap.isAvailable, isTrue);
      expect(bootstrap.authGateway, same(customGateway));
    });
  });
}
