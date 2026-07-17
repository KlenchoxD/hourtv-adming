import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/cast_service.dart';

void main() {
  group('CastService', () {
    test('reconoce HLS y MP4 aunque la URL tenga query params', () {
      expect(
        CastService.contentTypeFor('https://cdn.test/movie/master.m3u8?t=1'),
        'application/x-mpegURL',
      );
      expect(
        CastService.contentTypeFor(
          'https://cdn.test/movie/video.mp4?token=abc',
        ),
        'video/mp4',
      );
    });

    test('rechaza esquemas y formatos no compatibles', () {
      expect(CastService.isNetworkUrl('archive:movie'), isFalse);
      expect(CastService.contentTypeFor('https://cdn.test/video.ts'), isNull);
    });

    test('detecta User-Agent que el receptor por defecto no puede enviar', () {
      expect(CastService.needsUnsupportedHeaders('HourTV/1.0'), isTrue);
      expect(CastService.needsUnsupportedHeaders('  '), isFalse);
      expect(CastService.needsUnsupportedHeaders(null), isFalse);
    });
  });
}
