import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/new_ui/hourtv_detail_page.dart';
import 'package:streamtv/services/catalog/hero_tag_helper.dart';
import 'package:streamtv/services/device_type.dart';

void main() {
  group('Hero Tag Collision Prevention', () {
    test('makeHeroTag produces consistent and distinct scoped tags', () {
      final tag1 = makeHeroTag(contextScope: 'home_trends', id: 'movie_1');
      final tag2 = makeHeroTag(contextScope: 'home_recommended', id: 'movie_1');
      final tag3 = makeHeroTag(contextScope: 'search', id: 'movie_1');

      expect(tag1, isNot(equals(tag2)));
      expect(tag1, isNot(equals(tag3)));
      expect(tag2, isNot(equals(tag3)));
      expect(tag1, contains('home_trends'));
      expect(tag1, contains('movie_1'));
    });

    testWidgets('Multiple cards with identical item in different sections render without Hero tag collisions', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final channel = Channel(
        tvgId: 'movie_dup',
        name: 'Dune Part Two',
        url: 'https://example.com/dune.mp4',
        logo: 'https://example.com/dune.jpg',
        forcedType: 'movie',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Row 1: Tendencias
                  HourTvPosterCard(
                    channel: channel,
                    heroScope: 'row_tendencias',
                    onTap: () {},
                  ),
                  // Row 2: Recomendados
                  HourTvPosterCard(
                    channel: channel,
                    heroScope: 'row_recomendados',
                    onTap: () {},
                  ),
                  // Row 3: Continuar Viendo
                  HourTvPosterCard(
                    channel: channel,
                    heroScope: 'row_continuar',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify no duplicate Hero exceptions were thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(Hero), findsNWidgets(3));
    });

    testWidgets('Detail page accepts matching heroScope and transitions seamlessly', (tester) async {
      DeviceProfile.overrideType.value = DeviceType.phone;
      addTearDown(() => DeviceProfile.overrideType.value = null);

      final channel = Channel(
        tvgId: 'movie_detail_hero',
        name: 'Interstellar',
        url: 'https://example.com/interstellar.mp4',
        logo: 'https://example.com/interstellar.jpg',
        forcedType: 'movie',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvDetailPage(
            channel: channel,
            preview: false,
            heroScope: 'row_tendencias',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final heroFinder = find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == makeHeroTag(contextScope: 'row_tendencias', id: 'movie_detail_hero'),
      );
      expect(heroFinder, findsOneWidget);
    });
  });
}
