import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamtv/services/logo_image_provider.dart';

void main() {
  test('baja el logo una vez y después lo lee del disco', () async {
    final dir = await Directory.systemTemp.createTemp('logos_test');
    addTearDown(() => dir.delete(recursive: true));
    LogoImageProvider.debugCacheDir = dir;
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response.bytes([1, 2, 3], 200);
    });
    const url = 'https://example.com/logo.png';

    expect(await LogoImageProvider.loadBytes(url, client: client), [1, 2, 3]);
    // La escritura a disco va aparte: esperar a que el archivo exista.
    final file = await LogoImageProvider.fileFor(url);
    for (var i = 0; i < 50 && !file.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await LogoImageProvider.loadBytes(url, client: client), [1, 2, 3]);
    expect(requests, 1);
  });

  test('misma URL, misma clave de caché', () {
    expect(
      const LogoImageProvider('https://a/x.png'),
      const LogoImageProvider('https://a/x.png'),
    );
  });
}
