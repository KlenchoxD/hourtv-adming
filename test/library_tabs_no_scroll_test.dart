import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets(
    '"Mi Lista", "Continuar viendo" e "Historial" se ven las tres a la vez '
    'sin tener que arrastrar un carrusel horizontal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: HourTvMobileLibrary(
              store: ContentStore.instance,
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Las tres etiquetas deben existir en el arbol sin depender de
      // scroll: no estan dentro de un ListView horizontal recortado.
      expect(find.text('MI LISTA'), findsOneWidget);
      expect(find.text('CONTINUAR VIENDO'), findsOneWidget);
      expect(find.text('HISTORIAL'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);

      await tester.tap(find.text('HISTORIAL'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
