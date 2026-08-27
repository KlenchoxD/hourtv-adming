import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_controller.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_models.dart';
import 'package:streamtv/hybrid_mobile/screens/hybrid_search_screen.dart';
import 'package:streamtv/hybrid_mobile/theme/hybrid_mobile_theme.dart';
import 'package:streamtv/studio_ui/data/studio_media_item.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait(<Future<void>>[inter.load(), materialIcons.load()]);
  });

  testWidgets('shows editable history and catalog-driven popular searches', (
    tester,
  ) async {
    final catalog = await _catalog(_baseItems());
    addTearDown(catalog.dispose);
    final history = MemoryHybridSearchHistoryStore(<String>['Frontera Roja']);
    await tester.pumpWidget(
      _app(
        HybridSearchScreen(
          catalog: catalog,
          historyStore: history,
          onBack: () {},
          onOpenDetails: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Historial de búsquedas'), findsOneWidget);
    expect(find.text('Frontera Roja'), findsWidgets);
    expect(find.text('Búsquedas populares'), findsOneWidget);
    expect(find.text('Álma de cristal'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Eliminar Frontera Roja'));
    await tester.pump();
    expect(history.values, isEmpty);
  });

  testWidgets(
    'filters live without accents and persists only submitted queries',
    (tester) async {
      final catalog = await _catalog(_baseItems());
      addTearDown(catalog.dispose);
      final history = MemoryHybridSearchHistoryStore();
      HybridMediaItem? opened;
      await tester.pumpWidget(
        _app(
          HybridSearchScreen(
            catalog: catalog,
            historyStore: history,
            onBack: () {},
            onOpenDetails: (item) => opened = item,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('hybrid-search-field')),
        'alma de cristal',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1 resultado'), findsOneWidget);
      expect(find.text('Álma de cristal'), findsOneWidget);
      expect(history.values, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(history.values, <String>['alma de cristal']);
      await tester.tap(find.text('Álma de cristal'));
      await tester.pump();
      expect(opened?.id, 'alma');
    },
  );

  testWidgets('category and sort controls change the real result set', (
    tester,
  ) async {
    final catalog = await _catalog(_baseItems());
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      _app(
        HybridSearchScreen(
          catalog: catalog,
          historyStore: MemoryHybridSearchHistoryStore(),
          onBack: () {},
          onOpenDetails: (_) {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('hybrid-search-field')),
      'a',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Series'));
    await tester.pump();
    expect(find.text('Frontera Roja'), findsOneWidget);
    expect(find.text('Álma de cristal'), findsNothing);

    await tester.tap(find.byType(OutlinedButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orden A–Z'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Orden A–Z'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reveals more results progressively near the scroll end', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = await _catalog(<StudioMediaItem>[
      for (var index = 0; index < 42; index++)
        _media(
          id: 'title-$index',
          title: 'Título ${index.toString().padLeft(2, '0')}',
          kind: StudioMediaKind.movie,
          genre: 'Drama',
          year: '${2000 + index}',
        ),
    ]);
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      _app(
        HybridSearchScreen(
          catalog: catalog,
          historyStore: MemoryHybridSearchHistoryStore(),
          onBack: () {},
          onOpenDetails: (_) {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('hybrid-search-field')),
      'titulo',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(_gridCount(tester), 18);
    expect(find.text('42 resultados'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2200));
    await tester.pumpAndSettle();
    expect(_gridCount(tester), greaterThan(18));
  });

  testWidgets('shows a useful no-results state', (tester) async {
    final catalog = await _catalog(_baseItems());
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      _app(
        HybridSearchScreen(
          catalog: catalog,
          historyStore: MemoryHybridSearchHistoryStore(),
          onBack: () {},
          onOpenDetails: (_) {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('hybrid-search-field')),
      'no existe',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0 resultados'), findsOneWidget);
    expect(
      find.text('No encontramos títulos para esta búsqueda.'),
      findsOneWidget,
    );
  });

  testWidgets('matches the 393px empty and results visual baselines', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = await _catalog(_baseItems());
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      _app(
        HybridSearchScreen(
          catalog: catalog,
          historyStore: MemoryHybridSearchHistoryStore(<String>[
            'Frontera Roja',
          ]),
          onBack: () {},
          onOpenDetails: (_) {},
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(HybridSearchScreen),
      matchesGoldenFile('../goldens/search_empty_393.png'),
    );

    await tester.enterText(
      find.byKey(const ValueKey('hybrid-search-field')),
      'a',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(HybridSearchScreen),
      matchesGoldenFile('../goldens/search_results_393.png'),
    );
  });
}

int _gridCount(WidgetTester tester) => tester
    .widget<SliverGrid>(
      find.byKey(const ValueKey('hybrid-search-results-grid')),
    )
    .delegate
    .estimatedChildCount!;

Widget _app(Widget child) => MaterialApp(
  theme: HybridMobileTheme.dark(),
  home: Scaffold(body: SafeArea(child: child)),
);

Future<HybridCatalogController> _catalog(List<StudioMediaItem> items) async {
  final controller = HybridCatalogController(
    source: _SearchCatalogSource(items),
  );
  await controller.load();
  return controller;
}

List<StudioMediaItem> _baseItems() => <StudioMediaItem>[
  _media(
    id: 'alma',
    title: 'Álma de cristal',
    kind: StudioMediaKind.movie,
    genre: 'Ciencia ficción',
    year: '2023',
    featured: true,
  ),
  _media(
    id: 'frontera',
    title: 'Frontera Roja',
    kind: StudioMediaKind.series,
    genre: 'Drama',
    year: '2026',
  ),
  _media(
    id: 'horizonte',
    title: 'Horizonte cero',
    kind: StudioMediaKind.series,
    genre: 'Suspenso',
    year: '2024',
  ),
];

StudioMediaItem _media({
  required String id,
  required String title,
  required StudioMediaKind kind,
  required String genre,
  required String year,
  bool featured = false,
}) => StudioMediaItem(
  id: id,
  title: title,
  kind: kind,
  source: id,
  genre: genre,
  year: year,
  categories: <String>[genre],
  isFeatured: featured,
);

class _SearchCatalogSource extends ChangeNotifier
    implements HybridCatalogSource {
  _SearchCatalogSource(this.items);

  final List<StudioMediaItem> items;

  @override
  Future<void> ensureLoaded() async {}

  @override
  List<StudioMediaItem> snapshot() => items;

  @override
  Future<bool> toggleMyList(StudioMediaItem item) async => !item.isFavorite;
}

class MemoryHybridSearchHistoryStore implements HybridSearchHistoryStore {
  MemoryHybridSearchHistoryStore([List<String> initial = const <String>[]])
    : values = <String>[...initial];

  List<String> values;

  @override
  Future<List<String>> load() async => <String>[...values];

  @override
  Future<void> save(List<String> history) async {
    values = <String>[...history];
  }
}
