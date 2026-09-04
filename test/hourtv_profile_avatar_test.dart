import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_profile_avatar.dart';

void main() {
  testWidgets(
    'el avatar de perfil es estable para el mismo nombre y cae a un '
    'circulo con icono si la imagen no carga (sin conexion en tests)',
    (tester) async {
      expect(
        profileAvatarUrl('Kids'),
        profileAvatarUrl('Kids'),
        reason: 'el mismo perfil siempre debe pedir el mismo avatar',
      );
      expect(
        profileAvatarUrl('Kids'),
        isNot(profileAvatarUrl('Invitado')),
        reason: 'perfiles distintos deben pedir avatares distintos',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HourTvProfileAvatar(profileName: 'Kids', radius: 32),
          ),
        ),
      );
      await tester.pump();
      // Sin red en tests: cae al fallback (icono), no debe crashear ni
      // dejar un hueco vacio.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
