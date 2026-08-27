import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _approvedLength = 108021;
const _approvedSha256 =
    '808fa7224ee8e3eaad2af054349c1322f447e87b4dc179fef3ea18aa951e9d69';

void main() {
  test('frozen XuperTV reference matches the approved source', () async {
    final reference = File('references/xupertv/index.html');

    expect(await reference.exists(), isTrue);
    final bytes = await reference.readAsBytes();
    expect(bytes, hasLength(_approvedLength));
    expect(sha256.convert(bytes).toString(), _approvedSha256);
  });

  test('reference manifest records the branding exception', () async {
    final manifest = await File(
      'references/xupertv/REFERENCE_MANIFEST.md',
    ).readAsString();

    expect(manifest, contains('HourTV'));
    expect(manifest, contains('must not be edited'));
    expect(manifest, contains(_approvedSha256.toUpperCase()));
  });
}
