import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the approved AI Studio export passes the integrity verifier', () async {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final powershell =
        '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
    final result = await Process.run(powershell, <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      'tool/verify_ai_studio_reference.ps1',
    ]);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      result.stdout,
      contains(
        'ED0D1FC439FC1CADFC0162ECFCBA0F050E973A1736CCEE0D93019AFCC84A53C0',
      ),
    );
  });
}
