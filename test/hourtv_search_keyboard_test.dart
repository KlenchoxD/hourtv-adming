import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_search_keyboard.dart';

void main() {
  Future<void> pumpKeyboard(
    WidgetTester tester, {
    required String initialQuery,
    required ValueChanged<String> onChanged,
  }) async {
    var query = initialQuery;
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TvSearchKeyboard(
              query: query,
              onChanged: (value) {
                setState(() => query = value);
                onChanged(value);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  test('el filtro busca progresivamente por todos los términos', () {
    expect(matchesTvSearch('Alma de cristal', 'alma de crista'), isTrue);
    expect(matchesTvSearch('El último amanecer', 'alma de crista'), isFalse);
    expect(matchesTvSearch('Alma de cristal', '  CRISTAL   alma '), isTrue);
  });

  testWidgets('el D-pad mueve el foco y OK activa la tecla enfocada', (
    tester,
  ) async {
    var query = '';
    await pumpKeyboard(
      tester,
      initialQuery: query,
      onChanged: (value) => query = value,
    );

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV Search A');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV Search B');
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('TV Search A'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(query, 'B');
  });

  testWidgets('Borrar limpia todo y Delete elimina un carácter', (
    tester,
  ) async {
    var query = 'alma';
    await pumpKeyboard(
      tester,
      initialQuery: query,
      onChanged: (value) => query = value,
    );

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(query, 'alm');

    await tester.tap(find.text('Borrar'));
    await tester.pump();
    expect(query, isEmpty);
    expect(find.text('Volver'), findsNothing);
  });

  testWidgets('arriba y abajo recorren la matriz y llegan a las acciones', (
    tester,
  ) async {
    var query = 'alma';
    await pumpKeyboard(
      tester,
      initialQuery: query,
      onChanged: (value) => query = value,
    );

    for (var step = 0; step < 5; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'TV Search Borrar todo',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(query, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV Search 3');
  });
}
