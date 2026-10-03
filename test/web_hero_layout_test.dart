import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_web_hero.dart';

void main() {
  testWidgets(
    'el banner web llena el fondo y mantiene acciones abajo a la izquierda',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var played = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1440,
              height: 800,
              child: HourTvWebHero(
                backdrop: const ColoredBox(
                  key: ValueKey('art'),
                  color: Colors.blue,
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Título real'),
                    TextButton(
                      onPressed: () => played = true,
                      child: const Text('Reproducir'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('art'))),
        const Size(1440, 800),
      );
      final title = tester.getTopLeft(find.text('Título real'));
      expect(title.dx, greaterThan(30));
      expect(title.dx, lessThan(100));
      expect(title.dy, greaterThan(500));
      await tester.tap(find.text('Reproducir'));
      expect(played, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
