import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HourTvMobileShell _allContent & Presentation Index Optimization Tests', () {
    testWidgets('CatalogPresentationIndex no se reconstruye repetitivamente en cada build()', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CatalogPresentationIndex.resetBuildCountForTest();

      ContentStore.instance.resetForTesting();
      final channels = [
        Channel(name: 'Movie 1', url: 'https://v/1', genre: 'Acción', forcedType: 'movie'),
        Channel(name: 'Movie 2', url: 'https://v/2', genre: 'Drama', forcedType: 'movie'),
        Channel(name: 'Series 1', url: 'https://v/3', genre: 'Comedia', forcedType: 'series'),
      ];
      ContentStore.instance.all = channels;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileShell(
              store: ContentStore.instance,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialBuildCount = CatalogPresentationIndex.buildCountForTest;
      expect(initialBuildCount, lessThanOrEqualTo(2));

      // Forzar múltiples rebuilds (por ejemplo, interacción táctil o scroll)
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // El índice NO debe haberse reconstruido en cada frame
      expect(CatalogPresentationIndex.buildCountForTest, equals(initialBuildCount));
    });
  });
}
