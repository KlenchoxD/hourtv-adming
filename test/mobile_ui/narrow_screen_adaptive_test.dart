import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_detail_page.dart';
import 'package:streamtv/new_ui/hourtv_series_detail_page.dart';
import 'package:streamtv/services/device_type.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  setUp(() {
    DeviceProfile.overrideType.value = DeviceType.phone;
    AdaptiveProfile.overrideLayoutSize.value = AdaptiveLayoutSize.compact;
    AdaptiveProfile.overrideInputMode.value = AdaptiveInputMode.touch;
  });

  tearDown(() {
    DeviceProfile.overrideType.value = null;
    AdaptiveProfile.overrideLayoutSize.value = null;
    AdaptiveProfile.overrideInputMode.value = null;
  });

  group('Narrow screen (< 360dp) responsiveness', () {
    testWidgets('HourTvBottomNavigation renders cleanly on 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HourTvBottomNavigation(
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(HourTvBottomNavigation), findsOneWidget);
      expect(find.text('INICIO'), findsOneWidget);
    });

    testWidgets('HourTvDetailPage actions render on 320dp without text clipping or overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final channel = Channel(
        tvgId: 'movie-1',
        name: 'Inception',
        url: 'http://example.com/movie.mp4',
        forcedType: 'movie',
        genre: 'Action, Sci-Fi',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvDetailPage(
            channel: channel,
            preview: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('REPRODUCIR'), findsOneWidget);
      expect(find.text('Favorito'), findsOneWidget);
      expect(find.text('Me gusta'), findsOneWidget);
    });

    testWidgets('HourTvSeriesDetailPage actions render on 320dp without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final series = XtreamSeries(
        seriesId: 'series-1',
        name: 'Breaking Bad',
        episodes: [
          Channel(
            name: 'Piloto',
            url: 'http://example.com/s1e1.mp4',
            group: 'Temporada 1',
            tvgId: 'S1:E1',
            forcedType: 'series',
          ),
        ],
        host: 'https://test.com',
        username: 'u',
        password: 'p',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvSeriesDetailPage(
            series: series,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Reproducir'), findsWidgets);
    });
  });
}
