import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/new_ui/hourtv_series_detail_page.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/device_type.dart';
import 'package:streamtv/services/playback_progress.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/xtream_service.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'hourtv_player_view_type_test.dart' show MockVideoPlayerPlatform;

class _EpisodePlaybackPlatform extends MockVideoPlayerPlatform {
  Duration? lastSeek;

  @override
  Future<void> seekTo(int textureId, Duration position) async =>
      lastSeek = position;

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(minutes: 45),
      size: const Size(1920, 1080),
    ),
  );
}

void main() {
  final episodes = [
    Channel(
      name: 'La llegada',
      url: 'https://example.test/one.mp4',
      tvgId: 'catalog:continue-design:1:1',
      group: 'T1',
      forcedType: 'series',
      duration: '42',
    ),
    Channel(
      name: 'Una pista',
      url: 'https://example.test/two.mp4',
      tvgId: 'catalog:continue-design:1:2',
      group: 'T1',
      forcedType: 'series',
      duration: '45',
    ),
    Channel(
      name: 'Otro comienzo',
      url: 'https://example.test/three.mp4',
      tvgId: 'catalog:continue-design:2:1',
      group: 'T2',
      forcedType: 'series',
      duration: '48',
    ),
  ];
  final series = XtreamSeries(
    seriesId: 'continue-design',
    name: 'Ciudad de sombras',
    host: '',
    username: '',
    password: '',
    episodes: episodes,
  );
  late VideoPlayerPlatform originalPlatform;
  late _EpisodePlaybackPlatform platform;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await PlaybackProgress.clear();
    ContentStore.instance.resetForTesting();
    DeviceProfile.overrideType.value = DeviceType.phone;
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _EpisodePlaybackPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() {
    DeviceProfile.overrideType.value = null;
    VideoPlayerPlatform.instance = originalPlatform;
    ContentStore.instance.resetForTesting();
  });

  Future<void> open(WidgetTester tester, {double width = 390}) async {
    await tester.binding.setSurfaceSize(Size(width, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: HourTvSeriesDetailPage(series: series)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> saveProgress() async {
    await PlaybackProgress.save(
      episodes[0],
      positionMs: 2520000,
      durationMs: 2520000,
    );
    await PlaybackProgress.save(
      episodes[1],
      positionMs: 1620000,
      durationMs: 2700000,
    );
  }

  testWidgets('destaca el episodio pendiente, no uno ya terminado', (
    tester,
  ) async {
    await tester.runAsync(saveProgress);
    await open(tester);
    final featured = find.byKey(const ValueKey('hourtv-continue-episode'));
    expect(featured, findsOneWidget);
    expect(
      find.descendant(of: featured, matching: find.text('2. Una pista')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: featured, matching: find.text('Quedan 18 min')),
      findsOneWidget,
    );
    expect(find.text('Visto'), findsOneWidget);
    expect(find.text('Todos los episodios'), findsOneWidget);
  });

  testWidgets('Continuar abre el capítulo correcto y reanuda su posición', (
    tester,
  ) async {
    await tester.runAsync(saveProgress);
    await open(tester);
    final button = find.descendant(
      of: find.byKey(const ValueKey('hourtv-continue-episode')),
      matching: find.text('Continuar'),
    );
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
    expect(player.channel.tvgId, 'catalog:continue-design:1:2');
    expect(player.initialIndex, 1);
    expect(player.resumePlayback, isTrue);
    expect(platform.lastSeek, const Duration(minutes: 27));
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
  });

  testWidgets('sin avance no inventa una tarjeta Sigue viendo', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('hourtv-continue-episode')), findsNothing);
    expect(find.text('Todos los episodios'), findsOneWidget);
    expect(find.text('1. La llegada'), findsOneWidget);
  });

  testWidgets('un capítulo abierto 5 segundos no oculta otro con avance real', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await saveProgress();
      await PlaybackProgress.save(
        episodes[0],
        positionMs: 5000,
        durationMs: 2520000,
      );
    });
    await open(tester);
    final featured = find.byKey(const ValueKey('hourtv-continue-episode'));
    expect(featured, findsOneWidget);
    expect(
      find.descendant(of: featured, matching: find.text('2. Una pista')),
      findsOneWidget,
    );
  });

  testWidgets('avance sin posición absoluta no ofrece una reanudación falsa', (
    tester,
  ) async {
    await tester.runAsync(
      () => PlaybackProgress.savePositionsFor(StorageService.activeProfileId, {
        PlaybackProgress.contentKey(episodes[1]): const SavedPosition(
          positionMs: 0,
          durationMs: 0,
          fraction: .4,
        ),
      }),
    );
    await open(tester);
    final featured = find.byKey(const ValueKey('hourtv-continue-episode'));
    expect(featured, findsNothing);
    expect(find.text('En progreso'), findsOneWidget);
  });

  testWidgets('el cambio de temporada oculta el pendiente de otra temporada', (
    tester,
  ) async {
    await tester.runAsync(saveProgress);
    await open(tester);
    expect(
      find.byKey(const ValueKey('hourtv-continue-episode')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Temporada 1').first);
    await tester.tap(find.text('Temporada 1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporada 2').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hourtv-continue-episode')), findsNothing);
    expect(find.text('1. Otro comienzo'), findsOneWidget);
    expect(find.text('2. Una pista'), findsNothing);
  });

  testWidgets('la tarjeta y lista caben en 320dp sin desbordarse', (
    tester,
  ) async {
    await tester.runAsync(saveProgress);
    await open(tester, width: 320);
    await tester.ensureVisible(
      find.byKey(const ValueKey('hourtv-continue-episode')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
