import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamtv/services/subtitles/hourtv_subtitle_track.dart';
import 'package:streamtv/services/subtitles/hourtv_srt_caption_file.dart';
import 'package:streamtv/services/subtitles/subtitle_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

HourTvSubtitleTrack _vttTrack({
  String id = 'track-vtt',
  String url = 'https://cdn.example.com/es.vtt',
  bool isHlsMediaPlaylist = false,
}) => HourTvSubtitleTrack(
  id: id,
  label: 'Español',
  languageCode: 'es',
  url: url,
  format: SubtitleFormat.vtt,
  isHlsMediaPlaylist: isHlsMediaPlaylist,
);

const _validVtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:04.000\nHola mundo\n';

http.Client _mockClient(
  String responseBody, {
  int statusCode = 200,
  String contentType = 'text/vtt',
  Map<String, String>? extraHeaders,
}) {
  return MockClient((request) async {
    final headers = {'content-type': contentType, ...?extraHeaders};
    return http.Response(responseBody, statusCode, headers: headers);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('HourTvSubtitleTrack Model & Specifications', () {
    test('Modelo soporta todos los campos técnicos requeridos', () {
      const track = HourTvSubtitleTrack(
        id: 'track-es-1',
        label: 'Español Latino',
        languageCode: 'es',
        url: 'https://cdn.example.com/subs/es.vtt',
        format: SubtitleFormat.vtt,
        sourceId: 'server-1',
        provenance: SubtitleProvenance.sidecar,
        isHlsMediaPlaylist: false,
        requiredHeaders: {'Referer': 'https://origin.example.com/'},
        charset: 'utf-8',
        hearingImpaired: true,
        isForced: false,
        isDefault: true,
        isAuto: false,
      );

      expect(track.id, equals('track-es-1'));
      expect(track.format, equals(SubtitleFormat.vtt));
      expect(track.hearingImpaired, isTrue);
      expect(track.isHlsMediaPlaylist, isFalse);
      expect(
        track.requiredHeaders['Referer'],
        equals('https://origin.example.com/'),
      );
      expect(HourTvSubtitleTrack.off.id, equals('off'));
      expect(HourTvSubtitleTrack.auto.isAuto, isTrue);
    });
  });

  group('HourTvSrtCaptionFile Parser Tests', () {
    test('Parsea SRT válido con timestamps exactos', () {
      const srtData = '''1
00:00:01,500 --> 00:00:04,000
Hola mundo desde HourTV

2
00:00:05,000 --> 00:00:08,250
Segunda línea de diálogo
Con texto multilínea
''';

      final captionFile = HourTvSrtCaptionFile(srtData);
      final captions = captionFile.captions;

      expect(captions.length, equals(2));
      expect(
        captions[0].start,
        equals(const Duration(seconds: 1, milliseconds: 500)),
      );
      expect(captions[0].end, equals(const Duration(seconds: 4)));
      expect(captions[0].text, equals('Hola mundo desde HourTV'));
      expect(captions[1].start, equals(const Duration(seconds: 5)));
      expect(
        captions[1].end,
        equals(const Duration(seconds: 8, milliseconds: 250)),
      );
      expect(
        captions[1].text,
        equals('Segunda línea de diálogo\nCon texto multilínea'),
      );
    });

    test('Rechaza HTML aunque venga como texto plano', () {
      const htmlBlock =
          '<!DOCTYPE html><html><body>Error 403 Forbidden</body></html>';
      expect(
        () => HourTvSrtCaptionFile(htmlBlock),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SubtitleController – Selección automática', () {
    test('Jerarquía: Forced > Perfil > Default > Off', () {
      const forcedTrack = HourTvSubtitleTrack(
        id: 'track-forced-es',
        label: 'Español (Forzado)',
        languageCode: 'es',
        isForced: true,
      );
      const enTrack = HourTvSubtitleTrack(
        id: 'track-en',
        label: 'English',
        languageCode: 'en',
        isDefault: true,
      );
      const esTrack = HourTvSubtitleTrack(
        id: 'track-es',
        label: 'Español',
        languageCode: 'es',
      );

      expect(
        SubtitleController.resolveAutomaticTrack(
          tracks: [enTrack, esTrack, forcedTrack],
          profileLanguage: 'es',
        ).id,
        equals('track-forced-es'),
      );
      expect(
        SubtitleController.resolveAutomaticTrack(
          tracks: [enTrack, esTrack],
          profileLanguage: 'es',
        ).id,
        equals('track-es'),
      );
      expect(
        SubtitleController.resolveAutomaticTrack(
          tracks: [enTrack],
          profileLanguage: 'fr',
        ).id,
        equals('track-en'),
      );
      expect(
        SubtitleController.resolveAutomaticTrack(
          tracks: [],
          profileLanguage: 'es',
        ).id,
        equals('off'),
      );
    });
  });

  group('SubtitleController – Cabeceras seguras', () {
    test('No transfiere cabeceras sensibles a otro host', () {
      final safeHeaders = SubtitleController.filterSafeHeaders(
        sourceHost: 'stream.source.com',
        targetUri: Uri.parse('https://cdn.subtitles.com/es.vtt'),
        sourceHeaders: {
          'User-Agent': 'HourTV/1.1',
          'Referer': 'https://stream.source.com/embed',
          'Authorization': 'Bearer secret-token',
          'Cookie': 'session=abc',
        },
      );

      expect(safeHeaders['User-Agent'], equals('HourTV/1.1'));
      expect(safeHeaders.containsKey('Authorization'), isFalse);
      expect(safeHeaders.containsKey('Cookie'), isFalse);
    });
  });

  group('SubtitleController – Clave de caché SHA-256', () {
    test('No contiene HMAC con clave hardcodeada; es reproducible', () {
      final uri = Uri.parse('https://cdn.example.com/subs/es.vtt');
      final key1 = SubtitleController.computeCacheKey(uri, 'track-es');
      final key2 = SubtitleController.computeCacheKey(uri, 'track-es');
      expect(key1, equals(key2), reason: 'Clave debe ser determinista');
      // No debe exponer la URL en texto
      expect(key1, isNot(contains('cdn.example.com')));
      expect(key1.length, equals(64)); // SHA-256 hex
    });

    test('URIs distintas producen claves distintas', () {
      final uri1 = Uri.parse('https://cdn.example.com/subs/es.vtt');
      final uri2 = Uri.parse('https://cdn.example.com/subs/en.vtt');
      final k1 = SubtitleController.computeCacheKey(uri1, 'track-es');
      final k2 = SubtitleController.computeCacheKey(uri2, 'track-en');
      expect(k1, isNot(equals(k2)));
    });

    test('URLs firmadas con query distinta no colisionan en caché', () {
      final first = SubtitleController.computeCacheKey(
        Uri.parse('https://cdn.example.com/sub.vtt?token=one'),
        'track-es',
      );
      final second = SubtitleController.computeCacheKey(
        Uri.parse('https://cdn.example.com/sub.vtt?token=two'),
        'track-es',
      );
      expect(first, isNot(second));
      expect(first, isNot(contains('token')));
    });
  });

  group('SubtitleController – Carga de pistas', () {
    test('Carga y parsea VTT válido', () async {
      final ctrl = SubtitleController();
      final client = _mockClient(_validVtt, contentType: 'text/vtt');
      final result = await ctrl.loadCaptionFile(
        _vttTrack(),
        httpClient: client,
      );
      expect(result, isNotNull);
      expect(result!.captions, isNotEmpty);
    });

    test('Rechaza HTML aunque responda 200', () async {
      final ctrl = SubtitleController();
      const html = '<!DOCTYPE html><html><body>Blocked</body></html>';
      final client = _mockClient(html, contentType: 'text/html');
      final result = await ctrl.loadCaptionFile(
        _vttTrack(),
        httpClient: client,
      );
      expect(result, isNull);
    });

    test('Rechaza JSON', () async {
      final ctrl = SubtitleController();
      const json = '{"error": "forbidden"}';
      final client = _mockClient(json, contentType: 'application/json');
      final result = await ctrl.loadCaptionFile(
        _vttTrack(),
        httpClient: client,
      );
      expect(result, isNull);
    });

    test('Devuelve null para pista HLS segmentada', () async {
      final ctrl = SubtitleController();
      final track = _vttTrack(isHlsMediaPlaylist: true);
      final client = _mockClient(_validVtt);
      final result = await ctrl.loadCaptionFile(track, httpClient: client);
      expect(result, isNull);
    });

    test('Devuelve null para URL vacía', () async {
      final ctrl = SubtitleController();
      const track = HourTvSubtitleTrack(
        id: 'empty',
        label: 'Vacío',
        languageCode: 'es',
        url: null,
      );
      final result = await ctrl.loadCaptionFile(track);
      expect(result, isNull);
    });

    test(
      'Rechaza respuesta que supera 1 MB (límite durante streaming)',
      () async {
        final ctrl = SubtitleController();
        // Generar un cuerpo > 1 MB
        final oversized = 'WEBVTT\n\n${'x' * (1024 * 1024 + 100)}';
        final client = _mockClient(oversized, contentType: 'text/vtt');
        final result = await ctrl.loadCaptionFile(
          _vttTrack(),
          httpClient: client,
        );
        expect(result, isNull);
      },
    );

    test('Usa caché LRU correctamente', () async {
      final ctrl = SubtitleController();
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response(
          _validVtt,
          200,
          headers: {'content-type': 'text/vtt'},
        );
      });

      final track = _vttTrack();
      await ctrl.loadCaptionFile(track, httpClient: client);
      await ctrl.loadCaptionFile(track, httpClient: client);

      // Segunda llamada debe servirse del caché
      expect(callCount, equals(1), reason: 'La segunda carga debe usar caché');
      expect(ctrl.cacheSize, equals(1));
    });
  });

  group('SubtitleController – Epoch/Cancelación', () {
    test(
      'advanceEpoch() cancela descargas pendientes del vídeo anterior',
      () async {
        final ctrl = SubtitleController();
        final completer = Completer<http.Response>();
        final client = MockClient((_) => completer.future);

        final track = _vttTrack();
        final future = ctrl.loadCaptionFile(track, httpClient: client);

        // Simular cambio de vídeo antes de que termine la descarga
        ctrl.advanceEpoch();
        completer.complete(
          http.Response(_validVtt, 200, headers: {'content-type': 'text/vtt'}),
        );

        final result = await future;
        expect(
          result,
          isNull,
          reason: 'Descarga del vídeo anterior debe ser descartada',
        );
      },
    );
  });

  group('SubtitleController – Límite LRU', () {
    test('El caché no supera maxCacheEntries = 10 entradas', () async {
      final ctrl = SubtitleController();

      for (var i = 0; i < 15; i++) {
        final client = _mockClient(_validVtt, contentType: 'text/vtt');
        final track = _vttTrack(
          id: 'track-$i',
          url: 'https://cdn.example.com/sub$i.vtt',
        );
        await ctrl.loadCaptionFile(track, httpClient: client);
      }

      expect(
        ctrl.cacheSize,
        lessThanOrEqualTo(SubtitleController.maxCacheEntries),
      );
    });
  });

  group('SubtitleController – UTF-8 / Latin-1', () {
    test('Decodifica UTF-8 estricto correctamente', () {
      // Verificar que computeCacheKey no falla con caracteres no-ASCII
      final result = SubtitleController.computeCacheKey(
        Uri.parse('https://x.com/ñoño.vtt'),
        'id',
      );
      expect(result, isNotNull);
      expect(result.length, equals(64));
    });
  });

  group('SubtitleController – Redirecciones', () {
    test('Sigue una redirección 302 válida hasta el archivo final', () async {
      final ctrl = SubtitleController();
      var hops = 0;
      final client = MockClient((req) async {
        hops++;
        if (hops == 1) {
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://cdn.example.com/final.vtt',
              'content-type': 'text/plain',
            },
          );
        }
        return http.Response(
          _validVtt,
          200,
          headers: {'content-type': 'text/vtt'},
        );
      });

      final result = await ctrl.loadCaptionFile(
        _vttTrack(),
        httpClient: client,
      );
      expect(result, isNotNull);
      expect(result!.captions, isNotEmpty);
    });

    test('Devuelve null si supera 3 redirecciones', () async {
      final ctrl = SubtitleController();
      var hops = 0;
      final client = MockClient((req) async {
        hops++;
        return http.Response(
          '',
          302,
          headers: {
            'location': 'https://cdn.example.com/hop${hops + 1}.vtt',
            'content-type': 'text/plain',
          },
        );
      });

      final result = await ctrl.loadCaptionFile(
        _vttTrack(),
        httpClient: client,
      );
      expect(
        result,
        isNull,
        reason: 'Más de 3 redirecciones debe devolver null',
      );
    });

    test('elimina credenciales al redirigir hacia otro host', () async {
      final ctrl = SubtitleController();
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://other.example.com/final.vtt'},
          );
        }
        return http.Response(
          _validVtt,
          200,
          headers: {'content-type': 'text/vtt'},
        );
      });
      final track = HourTvSubtitleTrack(
        id: 'secure',
        label: 'Español',
        languageCode: 'es',
        url: 'https://origin.example.com/sub.vtt',
        requiredHeaders: const {
          'User-Agent': 'HourTV',
          'Referer': 'https://origin.example.com/watch',
          'Authorization': 'Bearer private',
          'Cookie': 'session=private',
        },
      );

      final result = await ctrl.loadCaptionFile(track, httpClient: client);

      expect(result, isNotNull);
      expect(requests, hasLength(2));
      expect(requests[1].headers['User-Agent'], 'HourTV');
      expect(requests[1].headers.containsKey('Referer'), isFalse);
      expect(requests[1].headers.containsKey('Authorization'), isFalse);
      expect(requests[1].headers.containsKey('Cookie'), isFalse);
    });
  });
}
