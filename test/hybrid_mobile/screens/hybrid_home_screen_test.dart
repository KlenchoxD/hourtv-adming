import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/hybrid_mobile/components/hybrid_category_bar.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_controller.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_models.dart';
import 'package:streamtv/hybrid_mobile/screens/hybrid_home_screen.dart';
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

  testWidgets('renders the approved mixed XuperTV Home composition', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = await _catalog();
    addTearDown(catalog.dispose);

    await tester.pumpWidget(
      _app(
        HybridHomeScreen(
          catalog: catalog,
          onFilter: () {},
          onSearch: () {},
          onOpenDetails: (_) {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('HourTV'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('hybrid-home-banner')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<HybridCategoryBar>(find.byType(HybridCategoryBar))
          .categories,
      <String>[
        'Recomendado',
        'Infantil',
        'Terror',
        'Acción',
        'Comedia',
        'Romance',
        'Aventura',
      ],
    );
    expect(find.textContaining('CANALES EN DIRECTO'), findsNothing);
    expect(find.textContaining('Sintonizar'), findsNothing);

    final scrollable = _verticalScrollable();
    for (final title in <String>[
      'Películas más populares',
      'Series para maratonear',
      'Anime',
      'Novelas',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        250,
        scrollable: scrollable,
      );
      expect(find.text(title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters real content and opens the selected poster', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = await _catalog();
    addTearDown(catalog.dispose);
    HybridMediaItem? opened;

    await tester.pumpWidget(
      _app(
        HybridHomeScreen(
          catalog: catalog,
          onFilter: () {},
          onSearch: () {},
          onOpenDetails: (item) => opened = item,
        ),
      ),
    );

    await tester.tap(find.text('Terror'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Noche Oscura'),
      220,
      scrollable: _verticalScrollable(),
    );
    expect(find.text('Acción Total'), findsNothing);
    await tester.tap(find.text('Noche Oscura'));
    await tester.pump();
    expect(opened?.id, 'movie-terror');
  });

  testWidgets('header actions remain functional 48px targets', (tester) async {
    final catalog = await _catalog();
    addTearDown(catalog.dispose);
    var filters = 0;
    var searches = 0;
    await tester.pumpWidget(
      _app(
        HybridHomeScreen(
          catalog: catalog,
          onFilter: () => filters++,
          onSearch: () => searches++,
          onOpenDetails: (_) {},
        ),
      ),
    );

    for (final label in <String>['Filtrar', 'Buscar']) {
      final target = find.bySemanticsLabel(label);
      expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      await tester.tap(target);
      await tester.pump();
    }
    expect(filters, 1);
    expect(searches, 1);
  });

  testWidgets('matches the 393px Home visual baseline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = await _catalog();
    addTearDown(catalog.dispose);
    await tester.pumpWidget(
      _app(
        HybridHomeScreen(
          catalog: catalog,
          onFilter: () {},
          onSearch: () {},
          onOpenDetails: (_) {},
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(HybridHomeScreen),
      matchesGoldenFile('../goldens/home_393.png'),
    );
  });
}

Finder _verticalScrollable() => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

Widget _app(Widget child) => MaterialApp(
  theme: HybridMobileTheme.dark(),
  home: Scaffold(body: SafeArea(child: child)),
);

Future<HybridCatalogController> _catalog() async {
  final source = _HomeCatalogSource(<StudioMediaItem>[
    _media(
      id: 'movie-action',
      title: 'Acción Total',
      kind: StudioMediaKind.movie,
      genre: 'Acción',
      featured: true,
    ),
    _media(
      id: 'movie-terror',
      title: 'Noche Oscura',
      kind: StudioMediaKind.movie,
      genre: 'Terror',
    ),
    _media(
      id: 'series-drama',
      title: 'Frontera Roja',
      kind: StudioMediaKind.series,
      genre: 'Drama',
    ),
    _media(
      id: 'anime-action',
      title: 'Código Anime',
      kind: StudioMediaKind.series,
      genre: 'Anime · Acción',
    ),
    _media(
      id: 'novela-romance',
      title: 'Pasiones Cruzadas',
      kind: StudioMediaKind.series,
      genre: 'Telenovela · Romance',
    ),
  ]);
  final controller = HybridCatalogController(source: source);
  await controller.load();
  return controller;
}

StudioMediaItem _media({
  required String id,
  required String title,
  required StudioMediaKind kind,
  required String genre,
  bool featured = false,
}) => StudioMediaItem(
  id: id,
  title: title,
  kind: kind,
  source: id,
  genre: genre,
  year: '2026',
  isFeatured: featured,
  categories: genre.split(' · '),
);

class _HomeCatalogSource extends ChangeNotifier implements HybridCatalogSource {
  _HomeCatalogSource(this.items);

  final List<StudioMediaItem> items;

  @override
  Future<void> ensureLoaded() async {}

  @override
  List<StudioMediaItem> snapshot() => items;

  @override
  Future<bool> toggleMyList(StudioMediaItem item) async => !item.isFavorite;
}
