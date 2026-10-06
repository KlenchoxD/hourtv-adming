import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'hourtv_player_view_type_test.dart' show MockVideoPlayerPlatform;

class _PlaybackPlatform extends MockVideoPlayerPlatform {
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Future<void> play(int textureId) async => playCalls++;

  @override
  Future<void> pause(int textureId) async => pauseCalls++;
}

void main() {
  late _PlaybackPlatform platform;
  late VideoPlayerPlatform originalPlatform;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _PlaybackPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    VideoPlayerPlatform.instance = originalPlatform;
  });

  Future<void> openPlayer(WidgetTester tester, Channel channel) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(channel: channel, allChannels: [channel]),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final target in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('Live sin pausa ni atajos en $target', (tester) async {
      debugDefaultTargetPlatformOverride = target;
      await StorageService.saveSetting('autoPlay', false);
      final live = Channel(
        name: 'Canal de prueba',
        url: 'https://test.com/live.m3u8',
      );
      await openPlayer(tester, live);

      expect(platform.lastViewType, isNotNull);
      expect(
        platform.playCalls,
        greaterThan(0),
        reason: 'En vivo sintoniza incluso con autoplay VOD desactivado',
      );
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byTooltip('Pausar'), findsNothing);
      expect(find.byTooltip('Retroceder 10 segundos'), findsNothing);
      expect(find.byTooltip('Adelantar 10 segundos'), findsNothing);

      final pauses = platform.pauseCalls;
      for (final key in [
        LogicalKeyboardKey.mediaPause,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.mediaPlayPause,
      ]) {
        await tester.sendKeyEvent(key, platform: 'android');
        await tester.pump();
      }
      expect(
        platform.pauseCalls,
        pauses,
        reason: 'Los atajos no pausan un canal',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('VOD conserva reproducción manual y pausa', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await StorageService.saveSetting('autoPlay', false);
    final movie = Channel(
      name: 'Película de prueba',
      url: 'https://test.com/movie.mp4',
      forcedType: 'movie',
    );
    await openPlayer(tester, movie);

    expect(platform.lastViewType, isNotNull);
    expect(platform.playCalls, 0);
    expect(find.byTooltip('Reproducir'), findsOneWidget);
    await tester.tap(find.byTooltip('Reproducir'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(platform.playCalls, 1);
    expect(find.byTooltip('Pausar'), findsOneWidget);
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(platform.pauseCalls, greaterThan(0));
    expect(find.byTooltip('Reproducir'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}
