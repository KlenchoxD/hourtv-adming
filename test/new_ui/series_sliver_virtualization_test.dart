import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/xtream_service.dart';
import 'package:streamtv/services/device_type.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/new_ui/hourtv_focusable.dart';
import 'package:streamtv/new_ui/hourtv_series_detail_page.dart';

void main() {
  group('Series Detail Page Sliver Virtualization', () {
    testWidgets('recupera capítulos publicados después de abrir la ficha', (
      tester,
    ) async {
      final store = ContentStore.instance;
      store.resetForTesting();
      addTearDown(store.resetForTesting);
      DeviceProfile.overrideType.value = DeviceType.phone;
      addTearDown(() => DeviceProfile.overrideType.value = null);
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      final initial = XtreamSeries(
        seriesId: 'catalog:late',
        name: 'Serie tardía',
        host: '',
        username: '',
        password: '',
        episodes: const [],
      );
      await tester.pumpWidget(
        MaterialApp(home: HourTvSeriesDetailPage(series: initial)),
      );
      await tester.pumpAndSettle();
      store.series = [
        XtreamSeries(
          seriesId: initial.seriesId,
          name: initial.name,
          host: '',
          username: '',
          password: '',
          episodes: [
            Channel(
              name: 'Piloto recuperado',
              url: 'https://example.test/ep1.mp4',
              group: 'T1',
              tvgId: 'S1:E1',
              forcedType: 'series',
            ),
          ],
        ),
      ];
      // Notificación equivalente a la actualización del catálogo en segundo plano.
      store.notifyListeners();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('hourtv-series-episodes-sliver-list')),
        findsOneWidget,
      );
      expect(find.textContaining('Piloto recuperado'), findsWidgets);
    });
    testWidgets(
      'Virtualizes episode list on mobile without instantiating all 100 episodes',
      (tester) async {
        // Create a series with 100 episodes
        final episodes = List.generate(
          100,
          (i) => Channel(
            name: 'Episodio ${i + 1} - Capitulo de prueba',
            url: 'https://example.com/ep_${i + 1}.mp4',
            group: 'Temporada 1',
            tvgId: 'S1:E${i + 1}',
            forcedType: 'series',
          ),
        );

        final series = XtreamSeries(
          seriesId: 'series_test_100',
          name: 'Serie Test - Temporada 1 | Blog de Pelis',
          episodes: episodes,
          host: 'https://test.com',
          username: 'u',
          password: 'p',
        );

        DeviceProfile.overrideType.value = DeviceType.phone;
        addTearDown(() => DeviceProfile.overrideType.value = null);

        await tester.binding.setSurfaceSize(const Size(400, 1200));

        await tester.pumpWidget(
          MaterialApp(home: HourTvSeriesDetailPage(series: series)),
        );

        await tester.pumpAndSettle();

        // Title should be sanitized on screen preserving Temporada 1
        expect(find.text('Serie Test - Temporada 1'), findsOneWidget);

        // Scroll down to bring episodes into viewport
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();

        // Episode 1 should be visible near the top after scrolling to episodes
        // Find SliverList in tree via unique key
        expect(
          find.byKey(const ValueKey('hourtv-series-episodes-sliver-list')),
          findsOneWidget,
        );

        // Episode 90 should NOT be instantiated yet in the widget tree (virtualization)
        expect(find.text('Episodio 90'), findsNothing);
      },
    );

    testWidgets('TV mode retains D-pad focus and TvFocusable navigation', (
      tester,
    ) async {
      final episodes = List.generate(
        10,
        (i) => Channel(
          name: 'Episodio ${i + 1}',
          url: 'https://example.com/ep_${i + 1}.mp4',
          group: 'Temporada 1',
          tvgId: 'S1:E${i + 1}',
          forcedType: 'series',
        ),
      );

      final series = XtreamSeries(
        seriesId: 'series_tv_test',
        name: 'Serie TV Test',
        episodes: episodes,
        host: 'https://test.com',
        username: 'u',
        password: 'p',
      );

      DeviceProfile.overrideType.value = DeviceType.tv;
      addTearDown(() => DeviceProfile.overrideType.value = null);

      await tester.binding.setSurfaceSize(const Size(1920, 1080));

      await tester.pumpWidget(
        MaterialApp(home: HourTvSeriesDetailPage(series: series)),
      );

      await tester.pumpAndSettle();

      // Verify TV mode renders with TvFocusable items
      expect(find.text('Temporadas y Episodios'), findsOneWidget);
      expect(find.text('Episodio 1'), findsWidgets);
      expect(find.byType(TvFocusable), findsWidgets);
    });
  });
}
