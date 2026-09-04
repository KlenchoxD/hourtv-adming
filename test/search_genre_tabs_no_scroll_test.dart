import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';

void main() {
  testWidgets(
    'las 5 categorías de Buscar (Todo/Películas/Series/Anime/Novelas) se '
    'ven todas a la vez sin carrusel horizontal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final content = [
        Channel(name: 'Peli', url: 'http://a/1.mp4', forcedType: 'movie'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: HourTvMobileSearch(content: content, onOpen: (_) {}),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      expect(find.text('TODO'), findsOneWidget);
      expect(find.text('PELÍCULAS'), findsOneWidget);
      expect(find.text('SERIES'), findsOneWidget);
      expect(find.text('ANIME'), findsOneWidget);
      expect(find.text('NOVELAS'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);

      await tester.tap(find.text('ANIME'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
