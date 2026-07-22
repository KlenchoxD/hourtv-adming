import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/new_ui/hourtv_profile_page.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Future<void> render(
    WidgetTester tester, {
    required Size size,
    required bool phone,
    required bool tablet,
    required bool tv,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: HourTvProfilePage(phone: phone, tablet: tablet, tv: tv),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('perfil móvil renderiza contenido', (tester) async {
    await render(
      tester,
      size: const Size(390, 844),
      phone: true,
      tablet: false,
      tv: false,
    );
    expect(find.text('Tu Perfil'), findsOneWidget);
  });

  testWidgets('perfil tablet renderiza contenido', (tester) async {
    await render(
      tester,
      size: const Size(1024, 768),
      phone: false,
      tablet: true,
      tv: false,
    );
    expect(find.text('Ajustes del dispositivo'), findsOneWidget);
  });

  testWidgets('perfil escritorio renderiza contenido', (tester) async {
    await render(
      tester,
      size: const Size(1440, 900),
      phone: false,
      tablet: false,
      tv: false,
    );
    expect(find.text('Reproducción y calidad'), findsOneWidget);
  });

  testWidgets('perfil TV renderiza contenido', (tester) async {
    await render(
      tester,
      size: const Size(1920, 1080),
      phone: false,
      tablet: false,
      tv: true,
    );
    expect(find.text('Control parental'), findsOneWidget);
  });
}
