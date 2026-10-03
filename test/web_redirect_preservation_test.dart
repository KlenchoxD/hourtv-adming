import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/supabase_config.dart';

void main() {
  test('web conserva el origen y móvil conserva el enlace nativo', () {
    expect(
      SupabaseConfig.authRedirectUrl(
        isWeb: true,
        currentUri: Uri.parse('https://hourtv.pages.dev/?refresh=1'),
      ),
      'https://hourtv.pages.dev/',
    );
    expect(
      SupabaseConfig.authRedirectUrl(isWeb: false),
      SupabaseConfig.appRedirectUrl,
    );
    expect(
      () => SupabaseConfig.authRedirectUrl(
        isWeb: true,
        currentUri: Uri.parse('file:///app'),
      ),
      throwsArgumentError,
    );
  });
}
