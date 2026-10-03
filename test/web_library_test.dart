import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_web_library.dart';
import 'package:streamtv/models/channel.dart';

void main() {
  testWidgets('controles arriba a la derecha y selector compartido', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HourTvWebLibrary(
            items: const [],
            tab: 'Mi Lista',
            onTab: (_) {},
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );
    final search = tester.getRect(find.byType(TextField));
    final tabs = tester.getRect(find.text('Mi Lista'));
    final heading = tester.getRect(find.text('Tu colección, a tu manera'));
    expect(search.left, greaterThanOrEqualTo(heading.right));
    expect(search.bottom, lessThan(tabs.top));
    expect(
      tester.getRect(find.text('Recientes')).left,
      greaterThan(search.right),
    );
    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Películas'));
    await tester.pumpAndSettle();
    expect(find.text('Películas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'biblioteca busca, cambia pestaña y funciona en ventana estrecha',
    (tester) async {
      String? tab;
      await tester.binding.setSurfaceSize(const Size(500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvWebLibrary(
              items: [
                Channel(name: 'Backrooms', url: 'movie:1', forcedType: 'movie'),
              ],
              tab: 'Mi Lista',
              onTab: (v) => tab = v,
              onOpen: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Backrooms'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pumpAndSettle();
      expect(find.text('Backrooms'), findsNothing);
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(tab, 'Historial');
      expect(tester.takeException(), isNull);
    },
  );
}
