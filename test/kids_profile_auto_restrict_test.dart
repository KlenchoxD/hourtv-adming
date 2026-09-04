import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/new_ui/hourtv_profile_page.dart';
import 'package:streamtv/services/parental_control_service.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: HourTvProfilePage(phone: true, tablet: false, tv: false),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'salir de un perfil infantil sin el PIN correcto no deja cambiar de perfil',
    (tester) async {
      await ParentalControlService.enable('1357');
      await StorageService.createProfile(
        name: 'Mi Kids',
        avatarId: 'boy',
        isKids: true,
      );
      await StorageService.saveSetting('kidsAutoRestricted', true);

      await pumpProfile(tester);

      await tester.tap(find.text('Cambiar de perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Salir del perfil Kids'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '0000');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('PIN incorrecto.'), findsOneWidget);
      // Restringido sigue activo: no se salio del perfil infantil con el
      // PIN equivocado.
      expect(ParentalControlService.isEnabled, isTrue);
    },
  );

  testWidgets(
    'salir de un perfil infantil con el PIN correcto desactiva el modo '
    'restringido que ese perfil activo, y vuelve a exigir elegir perfil',
    (tester) async {
      await ParentalControlService.enable('1357');
      await StorageService.createProfile(
        name: 'Mi Kids',
        avatarId: 'boy',
        isKids: true,
      );
      await StorageService.saveSetting('kidsAutoRestricted', true);
      await StorageService.markProfileChosen();

      await pumpProfile(tester);

      await tester.tap(find.text('Cambiar de perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Salir del perfil Kids'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '1357');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(ParentalControlService.isEnabled, isFalse);
      expect(StorageService.hasChosenProfile.value, isFalse);
    },
  );
}
