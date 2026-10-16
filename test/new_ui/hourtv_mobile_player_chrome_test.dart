import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_mobile_player_chrome.dart';

void main() {
  testWidgets('landscape server pill stays aligned to the right safe inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HourTvMobilePlayerHeader(
            title: 'Película',
            serverLabel: 'VOE · Español',
            onBack: () {},
            onCast: () {},
          ),
        ),
      ),
    );
    final pill = find
        .ancestor(
          of: find.text('VOE · Español'),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getRect(pill).right, closeTo(784, 1));
  });
  for (final width in [320.0, 800.0]) {
    testWidgets('mobile chrome fits $width and large text without overflow', (
      tester,
    ) async {
      final height = width < 600 ? 800.0 : 360.0;
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Column(
                children: [
                  HourTvMobilePlayerHeader(
                    title:
                        'Un título muy largo para comprobar el espacio disponible',
                    subtitle: '2026 · Suspenso',
                    serverLabel: 'VOE · Español Latino',
                    onBack: () {},
                    onCast: () {},
                    onServer: () {},
                  ),
                  const Spacer(),
                  HourTvMobilePlayerToolbar(
                    qualityLabel: '1080p',
                    speedLabel: '1×',
                    landscape: true,
                    onAudio: () {},
                    onQuality: () {},
                    onSpeed: () {},
                    onPip: () {},
                    onSettings: () {},
                    onFullscreen: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('VOE · Español Latino'), findsOneWidget);
      expect(find.text('Audio y subtítulos'), findsOneWidget);
      final title = tester.widget<Text>(
        find.text('Un título muy largo para comprobar el espacio disponible'),
      );
      expect(title.style?.fontFamily, 'Roboto');
    });
  }

  testWidgets('all visible actions dispatch their own callback', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HourTvMobilePlayerHeader(
                title: 'Película',
                serverLabel: 'VOE · Español',
                onBack: () => calls.add('back'),
                onCast: () => calls.add('cast'),
                onServer: () => calls.add('server'),
              ),
              HourTvMobilePlayerToolbar(
                qualityLabel: 'Auto',
                speedLabel: '1×',
                landscape: true,
                onAudio: () => calls.add('audio'),
                onQuality: () => calls.add('quality'),
                onSpeed: () => calls.add('speed'),
                onPip: () => calls.add('pip'),
                onSettings: () => calls.add('settings'),
                onFullscreen: () => calls.add('fullscreen'),
              ),
            ],
          ),
        ),
      ),
    );
    for (final label in [
      'Volver',
      'Transmitir',
      'Cambiar servidor',
      'Audio y subtítulos',
      'Calidad',
      'Velocidad',
      'Picture-in-Picture',
      'Ajustes',
      'Vertical',
    ]) {
      await tester.tap(find.byTooltip(label));
    }
    expect(calls, [
      'back',
      'cast',
      'server',
      'audio',
      'quality',
      'speed',
      'pip',
      'settings',
      'fullscreen',
    ]);
  });

  testWidgets('single source is informational, not a fake selectable button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HourTvMobilePlayerHeader(
            title: 'Película',
            serverLabel: 'VOE · Español',
            onBack: () {},
            onCast: () {},
          ),
        ),
      ),
    );
    expect(find.text('VOE · Español'), findsOneWidget);
    expect(find.byTooltip('Cambiar servidor'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });
}
