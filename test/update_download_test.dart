import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test('reutiliza el APK completo y comparte descargas simultáneas', () async {
    final dir = await Directory.systemTemp.createTemp('hourtv-update-test');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response.add(List<int>.filled(64, 42));
      await request.response.close();
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
    try {
      final info = UpdateInfo(
        version: '99.0.123',
        downloadUrl: 'http://127.0.0.1:${server.port}/app.apk',
        notes: '',
        sizeBytes: 64,
      );
      final service = UpdateService.instance;
      final first = service.prepareUpdate(info);
      final second = service.prepareUpdate(info);
      expect(identical(first, second), isTrue);
      final path = await first;
      expect(await File(path).length(), 64);
      expect(requests, 1);
      expect(await service.prepareUpdate(info), path);
      expect(requests, 1);
    } finally {
      await server.close(force: true);
      await dir.delete(recursive: true);
    }
  });
}
