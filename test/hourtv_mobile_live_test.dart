import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_theme.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_live_page.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets(
    'la pestaña En Vivo muestra la guía completa directo, sin vista previa '
    'recortada ni un botón aparte para llegar a ella, y el selector de '
    'categorías (hoja inferior) filtra con los géneros reales',
    (WidgetTester tester) async {
      // Alto generoso para que la guia (bajo el reproductor, el buscador y
      // el selector de categoria) quede dentro del viewport sin depender de
      // hacer scroll.
      tester.view.physicalSize = const Size(390, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final channels = <Channel>[
        Channel(name: 'ESPN', url: 'live://espn', genre: 'Deportes'),
        Channel(name: 'Fox Sports', url: 'live://fox', genre: 'Deportes'),
        Channel(name: 'CNN', url: 'live://cnn', genre: 'Noticias'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: HourTvMobileTheme.build(),
          // Igual que dentro del shell real: HourTvLivePage no trae su
          // propio Scaffold, vive embebida en el Scaffold del shell.
          home: Scaffold(
            body: HourTvLivePage(
              channels: channels,
              preview: false,
              phone: true,
              tablet: false,
              tv: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // No debe existir ningun boton "Guía completa": la guia YA es lo que
      // se ve al entrar, no algo a lo que haya que navegar.
      expect(find.text('Guía completa'), findsNothing);

      // Categoria inicial: todos los canales, sin filtrar.
      expect(find.text('Todos los canales'), findsOneWidget);
      expect(find.text('ESPN'), findsOneWidget);
      expect(find.text('Fox Sports'), findsOneWidget);
      expect(find.text('CNN'), findsOneWidget);

      // Abre el selector de categorias (hoja inferior).
      await tester.tap(find.text('CATEGORÍA'));
      await tester.pumpAndSettle();

      // Sin categoria inventada: "Todos los canales" + "Favoritos" +
      // generos reales presentes, no mas.
      expect(find.text('Deportes'), findsOneWidget);
      expect(find.text('Noticias'), findsOneWidget);
      expect(find.text('Favoritos'), findsOneWidget);

      await tester.tap(find.text('Deportes'));
      await tester.pumpAndSettle();

      expect(find.text('ESPN'), findsOneWidget);
      expect(find.text('Fox Sports'), findsOneWidget);
      expect(find.text('CNN'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
