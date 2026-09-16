import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/auth/supabase_auth_gateway.dart';
import 'package:streamtv/services/supabase_config.dart';

void main() {
  group('P0 Google OAuth & Supabase Endpoints Verification', () {
    test('Valida literalmente el project-ref y las URLs canónicas sin confusiones ni variantes erróneas', () {
      // 1. Project Ref canónico estricto
      const expectedProjectRef = 'pzbehpbtuiyrerrzgkcd';
      expect(SupabaseConfig.defaultProjectRef, equals(expectedProjectRef));
      expect(SupabaseAuthGateway.defaultProjectRef, equals(expectedProjectRef));

      // 2. URL de callback de Google hacia Supabase (para configuración en Google Cloud Console)
      const expectedGoogleWebCallback = 'https://pzbehpbtuiyrerrzgkcd.supabase.co/auth/v1/callback';
      expect(SupabaseConfig.googleOAuthCallbackUrl, equals(expectedGoogleWebCallback));
      expect(SupabaseAuthGateway.googleOAuthWebCallbackUrl, equals(expectedGoogleWebCallback));

      // 3. URL de redirección desde Supabase hacia la app móvil (Deep link del cliente)
      const expectedAppRedirect = 'hourtv://auth-callback';
      expect(SupabaseConfig.appRedirectUrl, equals(expectedAppRedirect));
      expect(SupabaseAuthGateway.appRedirectUrl, equals(expectedAppRedirect));

      // 4. Verificación de que NO se confunden ambos valores
      expect(
        SupabaseConfig.googleOAuthCallbackUrl,
        isNot(equals(SupabaseConfig.appRedirectUrl)),
        reason: 'El callback web de Google hacia Supabase no debe confundirse con el deep link hacia la app',
      );

      final callbackUri = Uri.parse(SupabaseConfig.googleOAuthCallbackUrl);
      expect(callbackUri.scheme, equals('https'));
      expect(callbackUri.host, equals('pzbehpbtuiyrerrzgkcd.supabase.co'));
      expect(callbackUri.path, equals('/auth/v1/callback'));

      final appRedirectUri = Uri.parse(SupabaseConfig.appRedirectUrl);
      expect(appRedirectUri.scheme, equals('hourtv'));
      expect(appRedirectUri.host, equals('auth-callback'));

      // 5. Garantizar ausencia de la variante inexistente que no resuelve por DNS.
      const incorrectVariant = 'pzbehpbtujyerrzgkcd';
      expect(SupabaseConfig.defaultProjectRef.contains(incorrectVariant), isFalse);
      expect(SupabaseConfig.googleOAuthCallbackUrl.contains(incorrectVariant), isFalse);
      expect(SupabaseAuthGateway.googleOAuthWebCallbackUrl.contains(incorrectVariant), isFalse);
    });
  });
}
