import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVideoPlayerPlatform extends VideoPlayerPlatform with MockPlatformInterfaceMixin {
  VideoViewType? lastViewType;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int textureId) async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    lastViewType = options.viewType;
    return 1;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => Stream.value(VideoEvent(eventType: VideoEventType.initialized, duration: Duration(seconds: 10), size: Size(1920, 1080)));

  @override
  Widget buildView(int textureId) => Container();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => Container();
}

void main() {
  late MockVideoPlayerPlatform mockPlatform;

  setUp(() {
    debugDefaultTargetPlatformOverride = null;
    mockPlatform = MockVideoPlayerPlatform();
    VideoPlayerPlatform.instance = mockPlatform;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('PlayerScreen usa platformView en Android', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final channel = Channel(
      name: 'Test Stream',
      url: 'https://test.com/stream.mp4',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerScreen(channel: channel, allChannels: [channel]),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // wait for init

    expect(mockPlatform.lastViewType, equals(VideoViewType.platformView));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('PlayerScreen usa textureView en iOS', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final channel = Channel(
      name: 'Test Stream',
      url: 'https://test.com/stream.mp4',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerScreen(channel: channel, allChannels: [channel]),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // wait for init

    expect(mockPlatform.lastViewType, equals(VideoViewType.textureView));

    debugDefaultTargetPlatformOverride = null;
  });
}
