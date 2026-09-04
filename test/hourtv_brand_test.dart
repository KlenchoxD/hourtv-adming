import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_new_shell.dart';

void main() {
  testWidgets(
    'la marca en TV/tablet/desktop usa "Hour" en blanco y "TV" en pastilla '
    'verde solida, no el PNG rojo viejo ni el wordmark plano',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HourTvLogo(height: 48))),
      );

      expect(find.byType(HourTvLogo), findsOneWidget);
      // El logo viejo era un PNG (assets/branding/hourtv_logo.png) con los
      // colores de un diseño previo al rebrand a verde: no debe quedar
      // ningun Image dentro del wordmark.
      expect(
        find.descendant(
          of: find.byType(HourTvLogo),
          matching: find.byType(Image),
        ),
        findsNothing,
      );

      expect(find.text('Hour'), findsOneWidget);
      expect(find.text('TV'), findsOneWidget);

      final hourText = tester.widget<Text>(find.text('Hour'));
      expect(hourText.style?.color, Colors.white);

      final tvText = tester.widget<Text>(find.text('TV'));
      expect(
        tvText.style?.color,
        const Color(0xFF050505),
        reason: '"TV" va en negro/oscuro sobre el fondo verde de la pastilla',
      );

      final pillFinder = find.ancestor(
        of: find.text('TV'),
        matching: find.byType(DecoratedBox),
      );
      expect(pillFinder, findsOneWidget);
      final pill = tester.widget<DecoratedBox>(pillFinder);
      final decoration = pill.decoration as BoxDecoration;
      expect(
        decoration.color,
        const Color(0xFF00C781),
        reason: 'la pastilla de "TV" debe usar el verde de marca 0xFF00C781',
      );

      expect(tester.takeException(), isNull);
    },
  );
}
