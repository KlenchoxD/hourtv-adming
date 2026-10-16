import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamtv/services/local_hls_proxy.dart';

void main() {
  const origin = 'https://cdn.example.test/media/';
  final root = Uri.parse('${origin}cf-master.txt?k=secret&kx=expiry');

  Future<(int, String, Map<String, String>)> get(
    Uri url, {
    String? range,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      if (range != null) request.headers.set('Range', range);
      final response = await request.close();
      final headers = <String, String>{};
      response.headers.forEach(
        (name, values) => headers[name] = values.join(','),
      );
      return (
        response.statusCode,
        await utf8.decoder.bind(response).join(),
        headers,
      );
    } finally {
      client.close(force: true);
    }
  }

  test(
    'preserves master variants and routes disguised assets with scoped tokens',
    () async {
      final calls = <http.Request>[];
      final proxy = LocalHlsProxy(
        client: MockClient((request) async {
          calls.add(request);
          switch (request.url.path) {
            case '/media/cf-master.txt':
              return http.Response(
                '''#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="es",NAME="Español",URI="audio/index-a1.txt"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Español",URI="https://sub.example.test/es.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720,AUDIO="es"
720/index-f1.txt
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080,AUDIO="es"
1080/index-f1.txt
''',
                200,
                headers: {
                  'content-type':
                      'application/vnd.apple.mpegurl; charset=utf-8',
                },
              );
            case '/media/720/index-f1.txt':
              return http.Response('''#EXTM3U
#EXT-X-MAP:URI="../init.woff",BYTERANGE="80@0"
#EXT-X-KEY:METHOD=AES-128,URI="../key.bin?existing=1"
#EXTINF:5,
../segment.woff2?part=0
#EXT-X-ENDLIST
''', 200);
            default:
              return http.Response('asset', 200);
          }
        }),
      );
      addTearDown(proxy.close);
      final local = await proxy.start(
        root,
        headers: {
          'Origin': 'https://webflux.vip',
          'Referer': 'https://webflux.vip/',
          'Cookie': 'session=private',
        },
      );
      final master = (await get(local)).$2;
      expect(master, contains('RESOLUTION=1280x720'));
      expect(master, contains('RESOLUTION=1920x1080'));
      expect(master, contains('TYPE=AUDIO'));
      expect(master, isNot(contains('secret')));
      final playlist = master
          .split('\n')
          .firstWhere((line) => line.startsWith('http'));
      final media = (await get(Uri.parse(playlist))).$2;
      expect(media, contains('BYTERANGE="80@0"'));
      final init = RegExp(
        r'#EXT-X-MAP:URI="([^"]+)"',
      ).firstMatch(media)!.group(1)!;
      expect(Uri.parse(init).path, endsWith('.mp4'));
      await get(Uri.parse(init));
      final segment = media
          .split('\n')
          .firstWhere((line) => line.startsWith('http'));
      expect(Uri.parse(segment).path, endsWith('.m4s'));
      await get(Uri.parse(segment));
      expect(
        calls.last.url.toString(),
        '${origin}segment.woff2?part=0&k=secret&kx=expiry',
      );
      expect(calls.last.headers['origin'], 'https://webflux.vip');
      expect(calls.last.headers['cookie'], 'session=private');
      final key = RegExp(
        r'#EXT-X-KEY:METHOD=AES-128,URI="([^"]+)"',
      ).firstMatch(media)!.group(1)!;
      await get(Uri.parse(key));
      expect(
        calls.last.url.toString(),
        '${origin}key.bin?existing=1&k=secret&kx=expiry',
      );
      final subtitle = RegExp(
        r'TYPE=SUBTITLES[^\n]*URI="([^"]+)"',
      ).firstMatch(master)!.group(1)!;
      await get(Uri.parse(subtitle));
      expect(calls.last.url.query, isEmpty);
      expect(calls.last.headers.containsKey('cookie'), isFalse);
    },
  );

  test(
    'forwards Range and 206 metadata without buffering the whole asset',
    () async {
      final proxy = LocalHlsProxy(
        client: MockClient((request) async {
          if (request.url.path.endsWith('.txt')) {
            return http.Response('#EXTM3U\n#EXTINF:5,\nsegment.woff2\n', 200);
          }
          expect(request.headers['range'], 'bytes=2-4');
          return http.Response(
            'cde',
            206,
            headers: {
              'content-range': 'bytes 2-4/10',
              'accept-ranges': 'bytes',
            },
          );
        }),
      );
      addTearDown(proxy.close);
      final local = await proxy.start(root);
      final manifest = (await get(local)).$2;
      final segment = Uri.parse(
        manifest.split('\n').firstWhere((l) => l.startsWith('http')),
      );
      final result = await get(segment, range: 'bytes=2-4');
      expect(result.$1, 206);
      expect(result.$2, 'cde');
      expect(result.$3['content-range'], 'bytes 2-4/10');
      expect(result.$3['content-type'], contains('video/mp4'));
    },
  );

  test('reloads live manifests and rejects arbitrary URL injection', () async {
    var loads = 0;
    final proxy = LocalHlsProxy(
      client: MockClient((request) async {
        loads++;
        return http.Response(
          '#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:$loads\n#EXTINF:5,\n$loads.woff2\n',
          200,
        );
      }),
    );
    addTearDown(proxy.close);
    final local = await proxy.start(root);
    expect((await get(local)).$2, contains('MEDIA-SEQUENCE:1'));
    expect((await get(local)).$2, contains('MEDIA-SEQUENCE:2'));
    final forged = local.replace(
      path: '/seg.m4s',
      query: 'u=https://evil.test',
    );
    expect((await get(forged)).$1, 404);
    expect(loads, 2);
    await proxy.close();
    await expectLater(get(local), throwsA(isA<SocketException>()));
  });

  test('rejects a non-HLS response before returning a native source', () async {
    final proxy = LocalHlsProxy(
      client: MockClient((_) async => http.Response('<html>Error</html>', 200)),
    );
    addTearDown(proxy.close);
    await expectLater(proxy.start(root), throwsA(isA<FormatException>()));
  });

  test(
    'resolves relative assets against the final playlist after a redirect',
    () async {
      final calls = <http.Request>[];
      final proxy = LocalHlsProxy(
        client: MockClient((request) async {
          calls.add(request);
          if (request.url.host == 'cdn.example.test') {
            return http.Response(
              '',
              302,
              headers: {
                'location': 'https://other.example.test/new/index.txt?k=new',
              },
            );
          }
          if (request.url.path.endsWith('.txt')) {
            return http.Response('#EXTM3U\n#EXTINF:5,\nseg.woff2\n', 200);
          }
          return http.Response('bytes', 200);
        }),
      );
      addTearDown(proxy.close);
      final local = await proxy.start(root, headers: {'Cookie': 'private=1'});
      final manifest = (await get(local)).$2;
      final segment = Uri.parse(
        manifest.split('\n').firstWhere((l) => l.startsWith('http')),
      );
      await get(segment);
      expect(
        calls.last.url.toString(),
        'https://other.example.test/new/seg.woff2?k=new',
      );
      expect(calls.last.headers.containsKey('cookie'), isFalse);
    },
  );

  test(
    'selects cookies per resource path rather than copying manifest cookies',
    () async {
      final received = <String, String?>{};
      final proxy = LocalHlsProxy(
        cookiesFor: (uri) async =>
            uri.path.startsWith('/private/') ? 'private=1' : null,
        client: MockClient((request) async {
          received[request.url.path] = request.headers['cookie'];
          if (request.url.path.endsWith('.txt')) {
            return http.Response(
              '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="/keys/a.key"\n#EXTINF:5,\nseg.woff2\n',
              200,
            );
          }
          return http.Response('bytes', 200);
        }),
      );
      addTearDown(proxy.close);
      final local = await proxy.start(
        Uri.parse('https://cdn.test/private/index.txt?k=1'),
      );
      final manifest = (await get(local)).$2;
      final key = RegExp(r'URI="([^"]+)"').firstMatch(manifest)!.group(1)!;
      await get(Uri.parse(key));
      await get(
        Uri.parse(manifest.split('\n').firstWhere((l) => l.startsWith('http'))),
      );
      expect(received['/private/index.txt'], 'private=1');
      expect(received['/private/seg.woff2'], 'private=1');
      expect(received['/keys/a.key'], isNull);
    },
  );

  test('delivers media bytes before the upstream response completes', () async {
    final bytes = StreamController<List<int>>();
    final opened = Completer<void>();
    final proxy = LocalHlsProxy(
      client: MockClient.streaming((request, _) async {
        if (request.url.path.endsWith('.txt')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode('#EXTM3U\n#EXTINF:5,\nseg.woff2\n')),
            200,
          );
        }
        opened.complete();
        return http.StreamedResponse(bytes.stream, 200);
      }),
    );
    addTearDown(proxy.close);
    final local = await proxy.start(root);
    final manifest = (await get(local)).$2;
    final segment = Uri.parse(
      manifest.split('\n').firstWhere((l) => l.startsWith('http')),
    );
    final client = http.Client();
    addTearDown(client.close);
    final response = client.send(http.Request('GET', segment));
    await opened.future;
    bytes.add(List.filled(64 * 1024, 1));
    final firstChunk = Completer<void>();
    final allChunks = (await response).stream.listen((chunk) {
      if (!firstChunk.isCompleted) firstChunk.complete();
    });
    await firstChunk.future.timeout(const Duration(seconds: 2));
    expect(bytes.isClosed, isFalse);
    await bytes.close();
    await allChunks.cancel();
  });
}
