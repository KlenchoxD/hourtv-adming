import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_web_library.dart';
import 'package:streamtv/models/channel.dart';

void main() {
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
