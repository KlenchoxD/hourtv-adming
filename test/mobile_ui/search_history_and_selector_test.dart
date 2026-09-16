import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_compact_filter_selector.dart';

void main() {
  group('HourTvCompactFilterSelector & Virtualized Grid', () {
    testWidgets('Renders compact selector and opens bottom sheet with virtualized grid', (tester) async {
      String selected = 'Acción';
      final options = List.generate(40, (i) => 'Género $i');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HourTvCompactFilterSelector(
                label: 'GÉNERO',
                value: selected,
                options: options,
                onChanged: (val) => selected = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('GÉNERO'), findsOneWidget);
      expect(find.text('Acción'), findsOneWidget);

      // Tap to open sheet
      await tester.tap(find.byType(HourTvCompactFilterSelector));
      await tester.pumpAndSettle();

      // Verify sheet opened and shows options
      expect(find.text('Género 0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Select an option
      await tester.tap(find.text('Género 0'));
      await tester.pumpAndSettle();

      expect(selected, 'Género 0');
    });
  });
}
