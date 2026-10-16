import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamtv/services/temporary_playback_links.dart';

const source = 'https://gateway.example/source/movie-1';
Map<String, dynamic> ticket([String token = 'opaque-test-token']) => {
  'mode': 'protected',
  'url': 'https://gateway.example/media/$token',
  'headers': <String, String>{},
  'format': 'hls',
  'serverTime': 1800000000000,
  'expiresAt': 1800000000000 + const Duration(hours: 24).inMilliseconds,
};
void main() {
  test(
    'disabled by default and never classifies third-party links as managed',
    () {
      final disabled = TemporaryPlaybackLinks(gatewayOrigin: '');
      expect(disabled.manages(source), false);
      final client = TemporaryPlaybackLinks(
        gatewayOrigin: 'https://gateway.example',
      );
      for (final url in [
        'https://evil.example/source/movie-1',
        'https://gateway.example/source/movie-1?url=secret',
        'https://user@gateway.example/source/movie-1',
        'https://gateway.example/media/copied',
        'file:///source/movie-1',
      ]) {
        expect(client.manages(url), false, reason: url);
      }
      expect(client.manages(source), true);
    },
  );
  test(
    'fetches native HLS transparently using current session and no redirects',
    () async {
      final client = TemporaryPlaybackLinks(
        gatewayOrigin: 'https://gateway.example',
        sessionHeaders: () => {'Authorization': 'Bearer test-session'},
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/tickets/movie-1');
          expect(request.followRedirects, false);
          expect(request.headers['Authorization'], 'Bearer test-session');
          return http.Response(jsonEncode(ticket()), 200);
        }),
      );
      final result = await client.resolve(source);
      expect(result.url, 'https://gateway.example/media/opaque-test-token');
      expect(result.headers, isEmpty);
      expect(result.format, 'hls');
    },
  );
  test(
    'every subsequent playback gets a fresh ticket, concurrent requests share one',
    () async {
      var calls = 0;
      final release = Completer<void>();
      final client = TemporaryPlaybackLinks(
        gatewayOrigin: 'https://gateway.example',
        client: MockClient((_) async {
          calls++;
          if (calls == 1) await release.future;
          return http.Response(jsonEncode(ticket('token-$calls')), 200);
        }),
      );
      final one = client.resolve(source), two = client.resolve(source);
      release.complete();
      expect((await one).url, (await two).url);
      expect(calls, 1);
      expect((await client.resolve(source)).url, endsWith('/token-2'));
      expect(calls, 2);
    },
  );
  test(
    'switch OFF uses the direct native source and its provider headers',
    () async {
      final client = TemporaryPlaybackLinks(
        gatewayOrigin: 'https://gateway.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'mode': 'direct',
              'url': 'https://provider.example/video.mp4',
              'format': 'mp4',
              'headers': {'Referer': 'https://provider.example/'},
              'expiresAt': null,
            }),
            200,
          ),
        ),
      );
      final result = await client.resolve(source);
      expect(result.format, 'mp4');
      expect(result.headers['Referer'], 'https://provider.example/');
    },
  );
  for (final invalid in [
    {...ticket(), 'url': 'https://evil.example/media/stolen'},
    {...ticket(), 'expiresAt': 1800000000000},
    {
      ...ticket(),
      'headers': {'Authorization': 'provider-secret'},
    },
    {...ticket(), 'format': 'html'},
  ]) {
    test(
      'malformed or leaking protected tickets fail closed: ${invalid.keys.length} ${invalid['format']} ${invalid['expiresAt']}',
      () async {
        final client = TemporaryPlaybackLinks(
          gatewayOrigin: 'https://gateway.example',
          client: MockClient(
            (_) async => http.Response(jsonEncode(invalid), 200),
          ),
        );
        await expectLater(
          client.resolve(source),
          throwsA(isA<TemporaryPlaybackException>()),
        );
      },
    );
  }
  test(
    'redirect failure is generic and does not disclose ticket or provider response',
    () async {
      final client = TemporaryPlaybackLinks(
        gatewayOrigin: 'https://gateway.example',
        client: MockClient(
          (_) async => http.Response('provider-secret-url', 302),
        ),
      );
      try {
        await client.resolve(source);
        fail('expected rejection');
      } catch (error) {
        expect(error.toString(), isNot(contains('provider-secret-url')));
        expect(error.toString(), isNot(contains(source)));
      }
    },
  );
}
