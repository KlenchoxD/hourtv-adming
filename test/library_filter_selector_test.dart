import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets(
    'Mi Biblioteca usa un selector compacto (hoja inferior) para Películas/'
    'Series en vez de la fila de chips de antes, y el encabezado no '
    'desborda en una pantalla angosta',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = ContentStore.instance;
      store.all = [
        Channel(
          name: 'Peli',
          url: 'http://a/1.mp4',
          isFavorite: true,
          forcedType: 'movie',
        ),
        Channel(
          name: 'Serie',
          url: 'http://a/2.mp4',
          isFavorite: true,
          forcedType: 'series',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: HourTvMobileLibrary(store: store, onOpen: (_) {}),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      expect(find.text('Peli'), findsOneWidget);
      expect(find.text('Serie'), findsOneWidget);

      // No debe existir ya la fila de chips vieja.
      expect(find.text('PELÍCULAS'), findsNothing);

      // El selector compacto muestra el valor actual ("Todo").
      expect(find.text('TODO'), findsOneWidget);
      await tester.tap(find.text('TODO'));
      await tester.pumpAndSettle();

      expect(find.text('PELÍCULAS'), findsOneWidget);
      expect(find.text('SERIES'), findsOneWidget);

      await tester.tap(find.text('PELÍCULAS'));
      await tester.pumpAndSettle();

      expect(find.text('Peli'), findsOneWidget);
      expect(find.text('Serie'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
