import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/new_ui/hourtv_settings_playback_page.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('Mostrar subtítulos se guarda desde Reproducción y calidad', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HourTvPlaybackSettingsPage()),
    );
    expect(find.text('MOSTRAR SUBTÍTULOS'), findsOneWidget);
    expect(find.text('Automático'), findsOneWidget);

    await tester.tap(find.text('Siempre en español'));
    await tester.pump();
    expect(StorageService.getSetting('preferredSubtitleMode'), 'always');
    expect(StorageService.getSetting('preferredSubtitleLanguage'), 'es');

    await tester.ensureVisible(find.text('Desactivados'));
    await tester.tap(find.text('Desactivados'));
    await tester.pump();
    expect(StorageService.getSetting('preferredSubtitleMode'), 'off');
  });
}
