import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_new_shell.dart';

void main() {
  testWidgets('la marca nueva renderiza el logo oficial de HourTV', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HourTvLogo(height: 48))),
    );

    expect(find.byType(HourTvLogo), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HourTvLogo),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.text('HourTV'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
