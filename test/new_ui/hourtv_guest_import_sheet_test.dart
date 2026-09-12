import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_guest_import_sheet.dart';
import 'package:streamtv/services/migration/guest_data_importer.dart';

void main() {
  group('HourTvGuestImportSheet Widget Tests', () {
    testWidgets('1. Muestra resumen completo de datos encontrados en modo invitado', (tester) async {
      const summary = GuestImportSummary(
        favoritesCount: 5,
        progressCount: 2,
        historyCount: 8,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvGuestImportSheet(
              summary: summary,
              onImport: () async {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Datos encontrados del modo Invitado'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('En progreso'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Importar al perfil'), findsOneWidget);
      expect(find.text('Mantener separado'), findsOneWidget);
    });

    testWidgets('2. Ejecuta onImport al pulsar boton de importacion', (tester) async {
      bool importCalled = false;
      const summary = GuestImportSummary(
        favoritesCount: 1,
        progressCount: 0,
        historyCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvGuestImportSheet(
              summary: summary,
              onImport: () async {
                importCalled = true;
              },
              onCancel: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Importar al perfil'));
      await tester.pump();

      expect(importCalled, isTrue);
    });

    testWidgets('3. Ejecuta onCancel al pulsar boton de cancelar', (tester) async {
      bool cancelCalled = false;
      const summary = GuestImportSummary(
        favoritesCount: 1,
        progressCount: 0,
        historyCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvGuestImportSheet(
              summary: summary,
              onImport: () async {},
              onCancel: () {
                cancelCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mantener separado'));
      await tester.pump();

      expect(cancelCalled, isTrue);
    });
  });
}
