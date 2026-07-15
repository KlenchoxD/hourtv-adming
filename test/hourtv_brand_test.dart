import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/widgets/hourtv_brand.dart';

void main() {
  testWidgets('la marca HourTV renderiza el logo y el wordmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [HourTvLogo(size: 48), HourTvWordmark(fontSize: 20)],
          ),
        ),
      ),
    );

    expect(find.byType(HourTvLogo), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HourTvLogo),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(find.text('HourTV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
