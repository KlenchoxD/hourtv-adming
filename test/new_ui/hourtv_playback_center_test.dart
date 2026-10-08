import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_playback_center.dart';

void main() {
  late int playbackTaps;
  late int backwardTaps;
  late int forwardTaps;
  late int surfaceTaps;

  setUp(() {
    playbackTaps = backwardTaps = forwardTaps = surfaceTaps = 0;
  });

  Widget screen({
    bool controlsVisible = true,
    bool isBuffering = false,
    bool isPlaying = true,
  }) => MaterialApp(
    home: Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => surfaceTaps++,
        child: SizedBox.expand(
          child: HourTvPlaybackCenter(
            controlsVisible: controlsVisible,
            isBuffering: isBuffering,
            isPlaying: isPlaying,
            onTogglePlayback: () => playbackTaps++,
            onSeekBackward: () => backwardTaps++,
            onSeekForward: () => forwardTaps++,
          ),
        ),
      ),
    ),
  );

  testWidgets('buffering replaces pause, never overlays it', (tester) async {
    await tester.pumpWidget(screen());
    final pauseCenter = tester.getCenter(find.byIcon(Icons.pause_rounded));
    await tester.pumpWidget(screen(isBuffering: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(
      tester.getCenter(find.byType(CircularProgressIndicator)),
      pauseCenter,
    );
    expect(playbackTaps, 0);
    await tester.pumpWidget(screen());
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(playbackTaps, 0);
  });

  testWidgets('buffering does not force hidden controls to appear', (
    tester,
  ) async {
    await tester.pumpWidget(screen(controlsVisible: false, isBuffering: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    await tester.pumpWidget(screen(controlsVisible: false));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(playbackTaps, 0);
  });

  testWidgets('controls can hide and show while buffering continues', (
    tester,
  ) async {
    await tester.pumpWidget(screen(isBuffering: true));
    expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
    await tester.pumpWidget(screen(controlsVisible: false, isBuffering: true));
    expect(find.byIcon(Icons.replay_10_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(screen(isBuffering: true));
    expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
    expect(playbackTaps, 0);
  });

  testWidgets('loading surface tap reaches chrome toggle, not pause', (
    tester,
  ) async {
    await tester.pumpWidget(screen(controlsVisible: false, isBuffering: true));
    await tester.tapAt(
      tester.getCenter(find.byType(CircularProgressIndicator)),
    );
    expect(surfaceTaps, 1);
    expect(playbackTaps, 0);
  });

  testWidgets('loading is isolated in a small repaint boundary', (
    tester,
  ) async {
    await tester.pumpWidget(screen(isBuffering: true));
    final boundary = find
        .ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(RepaintBoundary),
        )
        .first;
    final renderObject = tester.renderObject<RenderRepaintBoundary>(boundary);
    expect(renderObject.size, const Size(76, 76));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused state stays paused after buffering ends', (tester) async {
    await tester.pumpWidget(screen(isPlaying: false, isBuffering: true));
    await tester.pumpWidget(screen(isPlaying: false));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(playbackTaps, 0);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(playbackTaps, 1);
  });

  testWidgets('transport callbacks only run on explicit user action', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.tap(find.byIcon(Icons.replay_10_rounded));
    await tester.tap(find.byIcon(Icons.forward_10_rounded));
    expect(playbackTaps, 1);
    expect(backwardTaps, 1);
    expect(forwardTaps, 1);
    expect(surfaceTaps, 0);
  });
}
