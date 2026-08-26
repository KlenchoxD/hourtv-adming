import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/studio_ui/components/studio_bottom_nav.dart';
import 'package:streamtv/studio_ui/components/studio_button.dart';
import 'package:streamtv/studio_ui/components/studio_logo.dart';
import 'package:streamtv/studio_ui/components/studio_media_card.dart';

import '../support/studio_test_fixtures.dart';
import 'studio_component_harness.dart';

void main() {
  setUpAll(loadStudioTestFonts);

  testWidgets(
    'bottom navigation exposes five destinations and only one active item',
    (tester) async {
      await tester.pumpWidget(const StudioComponentHarness(width: 393));

      expect(find.byType(StudioBottomNav), findsOneWidget);
      for (final label in <String>[
        'Inicio',
        'TV',
        'Buscar',
        'Mi Biblioteca',
        'Perfil',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey<String>('bottom-nav-selected-Inicio')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('bottom-nav-focus-outline')),
        findsNothing,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('bottom-nav-Inicio')))
            .height,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets('buttons center their content inside a 48 pixel touch target', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      StudioTestApp(
        child: Center(
          child: StudioButton(
            label: 'Reproducir',
            icon: Icons.play_arrow_rounded,
            onPressed: () => presses++,
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(StudioButton));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Reproducir'));
    expect(presses, 1);
  });

  testWidgets('favorite action does not also open the media card', (
    tester,
  ) async {
    var opens = 0;
    var toggles = 0;
    await tester.pumpWidget(
      StudioTestApp(
        child: Center(
          child: StudioMediaCard(
            item: StudioFixtures.movie,
            width: 120,
            onTap: () => opens++,
            onToggleFavorite: () => toggles++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('media-card-favorite')));
    expect(toggles, 1);
    expect(opens, 0);
  });

  testWidgets('component gallery renders at 360 pixels without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const StudioComponentHarness(width: 360));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(StudioMediaCard), findsOneWidget);
    expect(find.byType(StudioLogo), findsNWidgets(2));
  });

  testWidgets('component gallery matches the approved 393 pixel baseline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const RepaintBoundary(
        key: ValueKey<String>('component-gallery'),
        child: StudioComponentHarness(width: 393),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey<String>('component-gallery')),
      matchesGoldenFile('../goldens/components_393.png'),
    );
  });
}
