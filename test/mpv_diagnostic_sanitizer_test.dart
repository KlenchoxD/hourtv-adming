import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/mpv_video_player_platform.dart';

void main() {
  test(
    'keeps useful native errors while redacting signed URLs and headers',
    () {
      final diagnostic = sanitizeMpvDiagnostic(
        'HTTP 403 at https://user:pass@cdn.test/movie.m3u8?token=signed-value '
        'Authorization: Bearer bearer-secret Cookie: session=cookie-secret',
      );

      expect(diagnostic, contains('HTTP 403'));
      expect(diagnostic, contains('[url]'));
      expect(diagnostic, contains('Authorization=[redacted]'));
      expect(diagnostic, contains('Cookie=[redacted]'));
      expect(diagnostic, isNot(contains('user:pass')));
      expect(diagnostic, isNot(contains('signed-value')));
      expect(diagnostic, isNot(contains('bearer-secret')));
      expect(diagnostic, isNot(contains('cookie-secret')));
    },
  );

  test('bounds unusually long native error messages', () {
    final diagnostic = sanitizeMpvDiagnostic('x' * 500);

    expect(diagnostic.length, lessThanOrEqualTo(260));
  });
}
