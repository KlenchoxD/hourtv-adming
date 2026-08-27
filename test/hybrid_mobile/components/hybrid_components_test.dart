import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/hybrid_mobile/components/hybrid_bottom_navigation.dart';
import 'package:streamtv/hybrid_mobile/components/hybrid_brand_header.dart';
import 'package:streamtv/hybrid_mobile/components/hybrid_category_bar.dart';
import 'package:streamtv/hybrid_mobile/components/hybrid_overlay_menu.dart';
import 'package:streamtv/hybrid_mobile/components/hybrid_poster_card.dart';
import 'package:streamtv/hybrid_mobile/components/hybrid_section.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_models.dart';
import 'package:streamtv/hybrid_mobile/theme/hybrid_mobile_theme.dart';
import 'package:streamtv/hybrid_mobile/theme/hybrid_mobile_tokens.dart';
import 'package:streamtv/studio_ui/data/studio_media_item.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait(<Future<void>>[inter.load(), materialIcons.load()]);
  });

  testWidgets('header uses the approved HourTV brand and 48px actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: HybridBrandHeader(onFilter: () {}, onSearch: () {}),
      ),
    );

    expect(find.bySemanticsLabel('HourTV'), findsOneWidget);
    expect(find.textContaining('SuperTV'), findsNothing);
    for (final label in <String>['Filtrar', 'Buscar']) {
      final target = find.bySemanticsLabel(label);
      expect(target, findsOneWidget);
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('category bar has one selected item and reports taps', (
    tester,
  ) async {
    String selected = 'Recomendado';
    await tester.pumpWidget(
      _TestApp(
        child: StatefulBuilder(
          builder: (context, setState) => HybridCategoryBar(
            categories: const <String>['Recomendado', 'Infantil', 'Terror'],
            selected: selected,
            onSelected: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );

    expect(_selectedSemantics(tester), 1);
    expect(
      tester.widget<Text>(find.text('Recomendado')).style?.color,
      HybridMobileTokens.accent,
    );
    expect(
      tester.widget<Text>(find.text('Infantil')).style?.color,
      HybridMobileTokens.textSecondary,
    );
    await tester.tap(find.text('Terror'));
    await tester.pump();
    expect(selected, 'Terror');
    expect(_selectedSemantics(tester), 1);
  });

  testWidgets('bottom navigation keeps exactly one selected destination', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      _TestApp(
        child: StatefulBuilder(
          builder: (context, setState) => HybridBottomNavigation(
            selectedIndex: selectedIndex,
            onSelected: (index) => setState(() => selectedIndex = index),
          ),
        ),
      ),
    );

    expect(_selectedSemantics(tester), 1);
    await tester.tap(find.text('Buscar'));
    await tester.pump();
    expect(selectedIndex, 2);
    expect(_selectedSemantics(tester), 1);
  });

  testWidgets('poster cards share a 2:3 artwork ratio and stable height', (
    tester,
  ) async {
    final first = _item('one', 'Título corto');
    final second = _item('two', 'Un título deliberadamente largo de prueba');
    await tester.pumpWidget(
      _TestApp(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 110,
              child: HybridPosterCard(item: first, onTap: () {}),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: HybridPosterCard(item: second, onTap: () {}),
            ),
          ],
        ),
      ),
    );

    final ratios = tester.widgetList<AspectRatio>(
      find.byKey(const ValueKey<String>('hybrid-poster-artwork')),
    );
    expect(ratios, hasLength(2));
    expect(
      ratios.every(
        (ratio) => ratio.aspectRatio == HybridMobileTokens.posterAspectRatio,
      ),
      isTrue,
    );
    expect(
      tester.getSize(find.byType(HybridPosterCard).at(0)).height,
      tester.getSize(find.byType(HybridPosterCard).at(1)).height,
    );
  });

  testWidgets('overlay menu selects an item inside a narrow viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String selected = 'Temporada 1';
    await tester.pumpWidget(
      _TestApp(
        child: Align(
          alignment: Alignment.centerRight,
          child: StatefulBuilder(
            builder: (context, setState) => HybridOverlayMenu<String>(
              value: selected,
              values: const <String>[
                'Temporada 1',
                'Temporada 2',
                'Temporada 3',
              ],
              labelBuilder: (value) => value,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Temporada 1'));
    await tester.pumpAndSettle();
    expect(find.text('Temporada 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Temporada 3'));
    await tester.pumpAndSettle();
    expect(selected, 'Temporada 3');
  });

  testWidgets('section header keeps its optional action aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: HybridSectionHeader(title: 'Estrenos 2025', onViewAll: () {}),
      ),
    );

    expect(find.text('Estrenos 2025'), findsOneWidget);
    expect(find.text('Ver todo'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Estrenos 2025')).dy,
      tester.getTopLeft(find.text('Ver todo')).dy,
    );
  });

  testWidgets('component kit matches the 393px visual baseline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _TestApp(child: _ComponentGoldenHarness()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(_ComponentGoldenHarness),
      matchesGoldenFile('../goldens/components_393.png'),
    );
  });
}

int _selectedSemantics(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .where((widget) => widget.properties.selected == true)
    .length;

HybridMediaItem _item(String id, String title) => HybridMediaItem(
  kind: HybridMediaKind.movie,
  media: StudioMediaItem(
    id: id,
    title: title,
    kind: StudioMediaKind.movie,
    source: id,
    year: '2026',
    genre: 'Drama',
  ),
);

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: HybridMobileTheme.dark(),
    home: Scaffold(body: SafeArea(child: child)),
  );
}

class _ComponentGoldenHarness extends StatelessWidget {
  const _ComponentGoldenHarness();

  @override
  Widget build(BuildContext context) {
    final items = <HybridMediaItem>[
      _item('one', 'El último amanecer'),
      _item('two', 'Álma de cristal'),
      _item('three', 'Frontera Roja'),
    ];
    return Column(
      children: <Widget>[
        HybridBrandHeader(onFilter: () {}, onSearch: () {}),
        HybridCategoryBar(
          categories: const <String>[
            'Recomendado',
            'Infantil',
            'Terror',
            'Acción',
          ],
          selected: 'Recomendado',
          onSelected: (_) {},
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: HybridSectionHeader(title: 'Estrenos 2025', onViewAll: () {}),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var index = 0; index < items.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 10),
                Expanded(
                  child: HybridPosterCard(
                    item: items[index],
                    isInMyList: index == 0,
                    onMyList: () {},
                    onTap: () {},
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        HybridBottomNavigation(selectedIndex: 0, onSelected: (_) {}),
      ],
    );
  }
}
