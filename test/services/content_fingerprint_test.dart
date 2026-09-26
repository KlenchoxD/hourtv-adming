import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/content_fingerprint.dart';

void main() {
  test('huella estable para el mismo contenido y distinta ante un cambio', () {
    const catalog = '{"items":[{"id":"1","url":"https://a/1.m3u8"}]}';
    expect(fingerprintString(catalog), fingerprintString(catalog));
    // Un servidor reemplazado desde el panel (1 carácter) debe notarse.
    expect(
      fingerprintString(catalog),
      isNot(fingerprintString(catalog.replaceFirst('1.m3u8', '2.m3u8'))),
    );
    expect(
      fingerprintBytes(utf8.encode(catalog)),
      fingerprintBytes(utf8.encode(catalog)),
    );
  });

  test('combinar huellas depende del orden y de cada parte', () {
    expect(combineFingerprints([1, 'a', 2]), combineFingerprints([1, 'a', 2]));
    expect(
      combineFingerprints([1, 'a', 2]),
      isNot(combineFingerprints([2, 'a', 1])),
    );
    expect(
      combineFingerprints([1, 'a', null]),
      isNot(combineFingerprints([1, 'a', 'x'])),
    );
  });
}
