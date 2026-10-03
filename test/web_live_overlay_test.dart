import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_web_live_overlay.dart';

void main() {
  testWidgets('controles de vivo funcionan y no inventan programación', (
    tester,
  ) async {
    var pause = 0, mute = 0, fullscreen = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 840,
            height: 470,
            child: HourTvWebLiveOverlay(
              channel: 'Fast&FunBox',
              currentTitle: 'Sports',
              playing: true,
              ready: true,
              volume: 1,
              fullscreen: false,
              onPause: () => pause++,
              onMute: () => mute++,
              onVolume: (_) {},
              onFullscreen: () => fullscreen++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('A continuación'), findsNothing);
    await tester.tap(find.byTooltip('Pausar'));
    await tester.tap(find.byTooltip('Silenciar'));
    await tester.tap(find.byTooltip('Pantalla completa'));
      expect([pause, mute, fullscreen], [1, 1, 1]);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await expectLater(find.byType(HourTvWebLiveOverlay), matchesGoldenFile('goldens/web_live_overlay.png'));
  });
}
