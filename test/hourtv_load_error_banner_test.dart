import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_theme.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';

void main() {
  final demoMovie = Channel(
    name: 'Demo',
    url: 'preview://demo',
    forcedType: 'movie',
  );

  Widget pumpHome() => MaterialApp(
    theme: HourTvMobileTheme.build(),
    home: Scaffold(
      body: HourTvMobileHome(
        movies: [demoMovie],
        allContent: [demoMovie],
        store: ContentStore.instance,
        onOpen: (_) {},
        onSearch: () {},
        onProfile: () {},
      ),
    ),
  );

  testWidgets(
    'avisa cuando el catalogo real fallo y se muestra contenido de muestra',
    (WidgetTester tester) async {
      final store = ContentStore.instance;
      final previousAll = store.all;
      final previousError = store.error;
      addTearDown(() {
        store.all = previousAll;
        store.error = previousError;
      });

      store.all = [];
      store.error = 'SocketException: Failed host lookup';

      await tester.pumpWidget(pumpHome());

      expect(find.textContaining('No pudimos cargar el catálogo'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('no avisa nada si el catalogo real cargo bien', (
    WidgetTester tester,
  ) async {
    final store = ContentStore.instance;
    final previousAll = store.all;
    final previousError = store.error;
    addTearDown(() {
      store.all = previousAll;
      store.error = previousError;
    });

    store.all = [demoMovie];
    store.error = null;

    await tester.pumpWidget(pumpHome());

    expect(find.textContaining('No pudimos cargar el catálogo'), findsNothing);
  });
}
