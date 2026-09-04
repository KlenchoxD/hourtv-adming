import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/main.dart';
import 'package:streamtv/new_ui/hourtv_profile_avatars.dart';
import 'package:streamtv/new_ui/hourtv_profile_gate.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setUpFreshInstall(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'una instalación nueva (sin perfil creado) no ofrece ningún perfil '
    'prestablecido: obliga a crear uno, con al menos 6 caricaturas de '
    'hombres y mujeres para elegir',
    (tester) async {
      await setUpFreshInstall(tester);
      expect(StorageService.hasChosenProfile.value, isFalse);
      expect(StorageService.loadProfiles(), isEmpty);

      await tester.pumpWidget(const HourTVApp());
      // Pasa la pausa de marca de _LaunchSplash (900ms).
      await tester.pump(const Duration(milliseconds: 950));

      expect(find.byType(HourTvProfileGate), findsOneWidget);
      // Sin instalar nunca la app no debe verse ningun perfil listo para
      // usar: solo la eleccion de tipo de perfil a crear.
      expect(find.text('PERFIL NORMAL'), findsOneWidget);
      expect(find.text('PERFIL INFANTIL'), findsOneWidget);

      await tester.tap(find.text('PERFIL NORMAL'));
      await tester.pumpAndSettle();

      expect(
        HourTvAvatarCatalog.adults.length,
        greaterThanOrEqualTo(6),
        reason: 'debe haber minimo 6 caricaturas de adultos para elegir',
      );
      for (final option in HourTvAvatarCatalog.adults) {
        expect(find.text(option.label.toUpperCase()), findsOneWidget);
      }

      await tester.tap(find.text(HourTvAvatarCatalog.adults.first.label.toUpperCase()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump();
      await tester.tap(find.text('CREAR PERFIL'));
      await tester.pumpAndSettle();

      expect(StorageService.hasChosenProfile.value, isTrue);
      expect(find.byType(HourTvProfileGate), findsNothing);
      final profiles = StorageService.loadProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first['name'], 'Ana');
      expect(profiles.first['isKids'], isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el perfil infantil ofrece exactamente 2 caricaturas: una de niño y '
    'una de niña',
    (tester) async {
      await setUpFreshInstall(tester);

      await tester.pumpWidget(const HourTVApp());
      // Pasa la pausa de marca de _LaunchSplash (900ms).
      await tester.pump(const Duration(milliseconds: 950));

      await tester.tap(find.text('PERFIL INFANTIL'));
      await tester.pumpAndSettle();

      expect(HourTvAvatarCatalog.kids, hasLength(2));
      expect(find.text('NIÑO'), findsOneWidget);
      expect(find.text('NIÑA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
