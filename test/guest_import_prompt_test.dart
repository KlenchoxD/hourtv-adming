import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_guest_import_prompt.dart';
import 'package:streamtv/services/migration/guest_migration_service.dart';

Widget testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest import prompt shows summary counts and buttons', (tester) async {
    const summary = GuestMigrationSummary(
      localProfileId: 'invitado',
      favoriteCount: 2,
      progressCount: 3,
      recentCount: 3,
    );

    GuestMigrationDecision? decision;

    await tester.pumpWidget(testApp(HourTvGuestImportPrompt(
      summary: summary,
      onDecision: (d) => decision = d,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Encontramos datos del modo invitado'), findsOneWidget);
    expect(
      find.textContaining('2 favoritos y progreso en 3 títulos podrán vincularse a este perfil'),
      findsOneWidget,
    );
    expect(find.text('Conservar para importar'), findsOneWidget);
    expect(find.text('Ahora no'), findsOneWidget);

    await tester.tap(find.text('Conservar para importar'));
    await tester.pumpAndSettle();

    expect(decision, GuestMigrationDecision.acceptedForPhase3);
  });

  testWidgets('guest import prompt handles decline button', (tester) async {
    const summary = GuestMigrationSummary(
      localProfileId: 'invitado',
      favoriteCount: 5,
      progressCount: 1,
      recentCount: 1,
    );

    GuestMigrationDecision? decision;

    await tester.pumpWidget(testApp(HourTvGuestImportPrompt(
      summary: summary,
      onDecision: (d) => decision = d,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(decision, GuestMigrationDecision.declined);
  });
}
