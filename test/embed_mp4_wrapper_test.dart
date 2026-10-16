import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamtv/services/embed_resolver.dart';

void main() {
  test(
    'follows the observed mp4 wrapper before extracting native media',
    () async {
      final visited = <String>[];
      final client = MockClient((request) async {
        visited.add(request.url.toString());
        if (request.url.path == '/') {
          return http.Response(
            'window.location.replace("r.php?h=fixture");',
            200,
          );
        }
        if (request.url.path == '/r.php') {
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://byseraguci.com/e/fixture/video.mp4'},
          );
        }
        return http.Response('file: "https://cdn.test/video.m3u8"', 200);
      });
      final result = await EmbedResolver.resolveForPlayback(
        'https://mp4.nu/?token=fixture',
        client: client,
      );
      expect(result.stream?.url, 'https://cdn.test/video.m3u8');
      expect(visited, hasLength(3));
      client.close();
    },
  );

  test(
    'does not fetch a generic page when the content ID exists only in a root fragment',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('<html>application shell</html>', 200);
      });

      final result = await EmbedResolver.resolveForPlayback(
        'https://provider.test/#video-id',
        client: client,
      );

      expect(calls, 0);
      expect(result.stream, isNull);
      expect(result.safeWebUrl, isNull);
      client.close();
    },
  );

  for (final destination in [
    'https://untrusted.test/e/fixture',
    'http://byseraguci.com/e/fixture',
    'https://user@byseraguci.com/e/fixture',
    'https://byseraguci.com:444/e/fixture',
  ]) {
    test('rejects unverified wrapper target $destination', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            'window.location.replace("r.php?h=fixture");',
            200,
          );
        }
        return http.Response('', 302, headers: {'location': destination});
      });
      final result = await EmbedResolver.resolveForPlayback(
        'https://mp4.nu/?token=fixture',
        client: client,
      );
      expect(result.stream, isNull);
      expect(calls, 2);
      client.close();
    });
  }
}
