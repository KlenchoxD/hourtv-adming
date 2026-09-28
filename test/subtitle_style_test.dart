import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/subtitles/subtitle_style.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('lee el estilo guardado en ajustes', () async {
    await StorageService.saveSetting('subtitleColor', 'yellow');
    await StorageService.saveSetting('subtitleBackground', 'outline');
    await StorageService.saveSetting('subtitleFontScale', 1.3);
    final style = SubtitleStyle.load();
    expect(style.textColor, const Color(0xFFFFE14D));
    expect(style.background, 'outline');
    expect(style.scale, 1.3);
  });

  testWidgets('sin caja usa contorno; con caja, fondo negro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            const SubtitleStyle(background: 'outline').build('A'),
            const SubtitleStyle(background: 'solid').build('B'),
          ],
        ),
      ),
    );
    final a = tester.widget<Text>(find.text('A'));
    expect(a.style!.shadows, isNotEmpty);
    expect(
      find.ancestor(of: find.text('A'), matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    final box = tester.widget<DecoratedBox>(
      find.ancestor(of: find.text('B'), matching: find.byType(DecoratedBox)),
    );
    expect((box.decoration as BoxDecoration).color, Colors.black);
  });
}
