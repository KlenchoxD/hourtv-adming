import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_mobile_player_chrome.dart';
import 'package:streamtv/new_ui/hourtv_player_surfaces.dart';
import 'package:streamtv/new_ui/hourtv_cast_sheet.dart';

void main() {
  testWidgets(
    'chrome fades out before removal and cannot receive hidden taps',
    (tester) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, value, _) => PlayerChromeVisibility(
                visible: value,
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Opciones'),
                ),
              ),
            ),
          ),
        ),
      );
      final position = tester.getCenter(find.text('Opciones'));
      visible.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Opciones'), findsOneWidget);
      await tester.tapAt(position);
      expect(taps, 0);
      await tester.pump(const Duration(milliseconds: 360));
      expect(find.text('Opciones'), findsNothing);
      visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Opciones'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      await tester.pump(const Duration(milliseconds: 280));
      await tester.tap(find.text('Opciones'));
      expect(taps, 1);
    },
  );

  testWidgets('rapid taps reverse one fade without duplicate controls', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, value, _) => PlayerChromeVisibility(
              visible: value,
              child: const Text('Control único'),
            ),
          ),
        ),
      ),
    );
    double opacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('Control único'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final halfway = opacity();
    expect(halfway, greaterThan(.2));
    expect(halfway, lessThan(.8));
    visible.value = true;
    await tester.pump();
    expect(opacity(), closeTo(halfway, .001));
    await tester.pump(const Duration(milliseconds: 80));
    expect(opacity(), greaterThan(halfway));
    expect(find.text('Control único'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('scrim and controls share fade and scrim covers cutout inset', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(left: 40)),
          child: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, value, _) => Stack(
                children: [
                  Positioned.fill(child: HourTvPlayerScrim(visible: value)),
                  Positioned.fill(
                    child: SafeArea(
                      child: PlayerChromeVisibility(
                        visible: value,
                        child: const Text('Cabecera'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final scrim = find.byType(HourTvPlayerScrim);
    expect(tester.getRect(scrim).left, 0);
    visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final fades = tester
        .widgetList<FadeTransition>(
          find.descendant(
            of: find.byType(Stack).first,
            matching: find.byType(FadeTransition),
          ),
        )
        .map((fade) => fade.opacity.value)
        .where((value) => value < 1)
        .toList();
    expect(fades.length, 2);
    expect(fades[0], closeTo(fades[1], .001));
    expect(fades[0], closeTo(.5, .05));
    await tester.pumpAndSettle();
    expect(find.text('Cabecera'), findsNothing);
  });

  testWidgets('settings uses Mi lista and keeps callbacks functional', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HourTvPlayerOptionsSheet(
            title: 'Opciones de reproducción',
            subtitle: 'Película',
            actions: [
              PlayerSheetAction(
                icon: Icons.bookmark_rounded,
                label: 'En Mi lista',
                selected: true,
                onTap: () => taps++,
              ),
              PlayerSheetAction(
                icon: Icons.audiotrack_rounded,
                label: 'Audio',
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.favorite), findsNothing);
    await tester.tap(find.text('En Mi lista'));
    await tester.tap(find.text('Audio'));
    expect(taps, 2);
    expect(
      tester.widget<Text>(find.text('En Mi lista')).style?.fontFamily,
      'Roboto',
    );
  });

  testWidgets(
    'cast uses the same typography and can close without connecting',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCastSheet(
                  context,
                  title: 'Película',
                  media: () async => null,
                  blockedReason: 'Fuente no disponible para transmitir',
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Transmitir a TV'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Transmitir a TV')).style?.fontFamily,
        'Roboto',
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cerrar transmisión'));
      await tester.pumpAndSettle();
      expect(find.text('Transmitir a TV'), findsNothing);
    },
  );
}
