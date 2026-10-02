import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:streamtv/services/embed_resolver.dart';

// Prueba manual explícita; las pruebas unitarias y CI no dependen del proveedor.
void main() {
  test(
    'proveedores reales del catálogo entregan un stream multimedia',
    () async {
      final catalogResponse = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/KlenchoxD/hourtv-adming/master/catalog.json',
        ),
      );
      final catalog = jsonDecode(catalogResponse.body) as Map;
      final samples = <String, List<String>>{};
      for (final series in catalog['series'] as List) {
        for (final season in series['seasons'] as List) {
          for (final episode in season['episodes'] as List) {
            for (final server in episode['servers'] as List) {
              final url = server['url'] as String;
              final host = Uri.parse(url).host;
              (samples[host] ??= []).add(url);
            }
          }
        }
      }
      for (final entry in samples.entries) {
        final urls = entry.value;
        for (final url in {urls.first, urls[urls.length ~/ 2], urls.last}) {
          final result = await EmbedResolver.resolveForPlayback(url);
          expect(result.stream, isNotNull, reason: 'Proveedor ${entry.key}');
          final stream = result.stream!;
          printOnFailure('Proveedor ${entry.key}, muestra ${urls.indexOf(url) + 1}, CDN ${Uri.parse(stream.url).host}');
          final response = await http
              .get(
                Uri.parse(stream.url),
                headers: {...stream.headers, 'Range': 'bytes=0-4095'},
              )
              .timeout(const Duration(seconds: 25));
          expect(
            response.statusCode,
            anyOf(200, 206),
            reason: 'HTTP ${entry.key}',
          );
          final type = response.headers['content-type'] ?? '';
          final prefix = utf8.decode(
            response.bodyBytes.take(100).toList(),
            allowMalformed: true,
          );
          expect(
            prefix.startsWith('#EXTM3U') || type.startsWith('video/'),
            isTrue,
            reason: 'Contenido multimedia ${entry.key}, tipo $type',
          );
        }
      }
    },
    skip: !const bool.fromEnvironment('LIVE_EMBED_PROBE'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
