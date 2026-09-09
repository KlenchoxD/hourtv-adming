import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';

void main() {
  testWidgets(
    'Buscar utiliza los selectores compactos TIPO y GÉNERO sin carrusel horizontal ni desborde',
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

      expect(find.text('TIPO'), findsOneWidget);
      expect(find.text('GÉNERO'), findsOneWidget);

      await tester.tap(find.text('TIPO'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Tipo de contenido'), findsOneWidget);
      expect(find.text('Todo'), findsWidgets);
      expect(find.text('Películas'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Novelas'), findsOneWidget);

      await tester.tap(find.text('Anime'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
