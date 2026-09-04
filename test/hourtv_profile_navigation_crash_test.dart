import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/main.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  StorageService.hasChosenProfile.value = true;

  testWidgets(
    'tocar "toca para cambiar de perfil" no debe crashear la app',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const HourTVApp());
      // Pasa la pausa de marca de _LaunchSplash (900ms).
      await tester.pump(const Duration(milliseconds: 950));

      await tester.tap(find.text('PERFIL'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Toca para cambiar de perfil'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
