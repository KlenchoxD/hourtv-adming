import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog_presentation_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('4000 channels and nested servers round-trip through compute', () async {
    final channels = List.generate(
      4000,
      (i) => Channel(
        name: 'Película $i',
        url: 'https://example.com/$i.mp4',
        forcedType: 'movie',
        plot: 'Descripción de prueba $i',
        genre: 'Acción',
        categories: const ['Acción'],
        servers: [
          ChannelServer(name: 'Servidor', url: 'https://example.com/$i.mp4'),
        ],
      ),
    );
    CatalogPresentationIndex.resetBuildCountForTest();
    final index = await compute(CatalogPresentationIndex.build, channels);
    expect(index.search(const CatalogQuery()).length, 4000);
    expect(
      index.search(const CatalogQuery(text: '3999')).single.servers.single.name,
      'Servidor',
    );
    expect(
      CatalogPresentationIndex.buildCountForTest,
      0,
      reason: 'Normalization must execute in the worker isolate',
    );
  });

  testWidgets(
    'pending shared index never builds synchronously and keeps typed query',
    (tester) async {
      final content = [
        Channel(
          name: 'Película única',
          url: 'https://example.com/a.mp4',
          forcedType: 'movie',
        ),
      ];
      Widget page(CatalogPresentationIndex? index) => MaterialApp(
        home: Scaffold(
          body: HourTvMobileSearch(
            content: content,
            onOpen: (_) {},
            presentationIndex: index,
            indexPending: index == null,
          ),
        ),
      );
      CatalogPresentationIndex.resetBuildCountForTest();
      await tester.pumpWidget(page(null));
      expect(
        find.byKey(const ValueKey('catalog-index-loading')),
        findsOneWidget,
      );
      expect(CatalogPresentationIndex.buildCountForTest, 0);
      await tester.enterText(
        find.byKey(const ValueKey('hourtv-mobile-search-field')),
        'única',
      );
      final index = await tester.runAsync(
        () => compute(CatalogPresentationIndex.build, content),
      );
      await tester.pumpWidget(page(index));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('catalog-index-loading')), findsNothing);
      expect(find.text('1 resultado'), findsOneWidget);
      expect(CatalogPresentationIndex.buildCountForTest, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
