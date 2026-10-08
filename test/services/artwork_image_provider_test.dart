import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/artwork_image_provider.dart';

Future<Uint8List> imageBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF00C781),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

Future<ui.Size> decodedSize(ImageProvider provider) async {
  final completer = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (info, _) => completer.complete(info),
    onError: (Object error, StackTrace? stack) =>
        completer.completeError(error, stack),
  );
  stream.addListener(listener);
  try {
    final info = await completer.future.timeout(const Duration(seconds: 10));
    final size = ui.Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    info.dispose();
    return size;
  } finally {
    stream.removeListener(listener);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  test(
    'wide image keeps proportions inside a portrait decode budget',
    () async {
      final memory = MemoryImage(await imageBytes(600, 300));
      final bounded = hourTvArtworkProvider(
        memory,
        cacheWidth: 120,
        cacheHeight: 178,
      );
      expect(await decodedSize(bounded), const ui.Size(120, 60));
      // Reproduce the old forced-resize behavior, not a layout/BoxFit issue.
      expect(
        await decodedSize(ResizeImage(memory, width: 120, height: 178)),
        const ui.Size(120, 178),
      );
    },
  );

  test(
    'portrait fallback in a hero is cropped, not decoded stretched',
    () async {
      final provider = hourTvArtworkProvider(
        MemoryImage(await imageBytes(600, 900)),
        cacheWidth: 160,
        cacheHeight: 90,
      );
      expect(await decodedSize(provider), const ui.Size(60, 90));
    },
  );

  test(
    'cold, warm and restarted image caches produce the same ratio',
    () async {
      final memory = MemoryImage(await imageBytes(600, 300));
      ImageProvider bounded() =>
          hourTvArtworkProvider(memory, cacheWidth: 120, cacheHeight: 178);
      final cold = await decodedSize(bounded());
      final warm = await decodedSize(bounded());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      final restarted = await decodedSize(bounded());
      expect(cold, const ui.Size(120, 60));
      expect(warm, cold);
      expect(restarted, cold);
    },
  );

  test(
    'small source images are not enlarged just to fill the budget',
    () async {
      final provider = hourTvArtworkProvider(
        MemoryImage(await imageBytes(20, 30)),
        cacheWidth: 342,
        cacheHeight: 513,
      );
      expect(await decodedSize(provider), const ui.Size(20, 30));
    },
  );

  test('no decode limits preserves the original provider', () async {
    final memory = MemoryImage(await imageBytes(20, 30));
    expect(hourTvArtworkProvider(memory), same(memory));
  });
}
