import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/main.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/new_ui/hourtv_live_page.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  StorageService.hasChosenProfile.value = true;

  bool activeOf(WidgetTester tester) => tester
      .widget<HourTvLivePage>(find.byType(HourTvLivePage, skipOffstage: false))
      .active;

  // "TV" tambien aparece dentro de la pastilla verde del logo HourTV en el
  // header: el tap de la pestaña debe apuntar solo a la barra de navegacion.
  Finder navTv(WidgetTester tester) => find.descendant(
    of: find.byType(HourTvBottomNavigation),
    matching: find.text('TV'),
  );

  testWidgets(
    'salir de la pestaña TV hacia otra no crashea y no deja la guía en '
    '"active" (la miniatura en vivo debe pausarse, no seguir sonando)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const HourTVApp());
      // Pasa la pausa de marca de _LaunchSplash (900ms).
      await tester.pump(const Duration(milliseconds: 950));

      // Entra a la pestaña TV: primera visita, construye la guia en vivo.
      await tester.tap(navTv(tester));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('TV EN VIVO'), findsOneWidget);
      expect(
        activeOf(tester),
        isTrue,
        reason: 'recien entrando a TV la miniatura debe quedar activa',
      );

      // Sale a Buscar: la guia sigue montada (IndexedStack la preserva,
      // pero eso no es lo que se está verificando aquí) y debe recibir
      // active:false para pausar/cerrar su miniatura.
      await tester.tap(find.text('BUSCAR'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        activeOf(tester),
        isFalse,
        reason:
            'al salir de TV el widget debe recibir active:false; si esto '
            'sigue en true, el audio no tiene forma de saber que debe '
            'cortarse',
      );

      // Vuelve a TV: no debe crashear al reanudar.
      await tester.tap(navTv(tester));
      await tester.pump(const Duration(milliseconds: 50));
      expect(activeOf(tester), isTrue);

      expect(tester.takeException(), isNull);
    },
  );
}
