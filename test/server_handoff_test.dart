import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_server_handoff.dart';

void main() {
  testWidgets('connection status fades only when playback is ready', (
    tester,
  ) async {
    Widget app(bool ready) => MaterialApp(
      home: Scaffold(
        body: HourTvServerHandoff(
          names: const ['Streamwish', 'VOE'],
          activeIndex: 1,
          ready: ready,
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    expect(find.text('Conectando…'), findsOneWidget);
    expect(find.text('VOE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Conectando…'), findsOneWidget);
    await tester.pumpWidget(app(true));
    expect(find.text('Conectado'), findsOneWidget);
    expect(find.text('Conectando…'), findsNothing);
    // Readiness should fade the existing panel, not cross-fade a keyed copy
    // over it while the poster layer is also dissolving.
    expect(find.text('VOE'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 140));
    expect(find.text('VOE'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final fade = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('hourtv-server-handoff-fade')),
    );
    expect(fade.opacity, 0);
  });

  testWidgets('the next server slides up into the active center slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget app(int activeIndex) => MaterialApp(
      home: Scaffold(
        body: HourTvServerHandoff(
          names: const ['Orion', 'Valstrax', 'Atlas'],
          activeIndex: activeIndex,
          ready: false,
        ),
      ),
    );

    await tester.pumpWidget(app(0));
    final before = tester.getCenter(find.text('Valstrax')).dy;
    await tester.pumpWidget(app(1));
    await tester.pump(const Duration(milliseconds: 140));
    final during = tester.getCenter(find.text('Valstrax')).dy;
    expect(during, lessThan(before));
    // Keep the spinner's repeating animation out of pumpAndSettle; only the
    // wheel's 280 ms position transition needs to complete here.
    await tester.pump(const Duration(milliseconds: 200));
    final after = tester.getCenter(find.text('Valstrax')).dy;
    expect(after, lessThan(during));
    final activeSlot = tester.getRect(
      find.byKey(const ValueKey('server-wheel-slot-1')),
    );
    expect(
      activeSlot.center.dy,
      closeTo(tester.getRect(find.byType(HourTvServerHandoff)).center.dy, 1),
    );
  });

  testWidgets('fits narrow portrait without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HourTvServerHandoff(
            names: ['A very long server name', 'Second'],
            activeIndex: 0,
            ready: false,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
