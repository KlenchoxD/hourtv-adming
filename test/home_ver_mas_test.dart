import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('"Ver más" abre la cuadrícula con la fila completa', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final movies = [
      for (var i = 0; i < 20; i++)
        Channel(
          name: 'Peli $i',
          url: 'http://a/$i.mp4',
          forcedType: 'movie',
        ),
    ];
    // Las filas del Inicio ahora leen categorias reales del store (antes
    // repartian widget.movies/allContent con distinto orden como relleno).
    final store = ContentStore.instance;
    final previousAll = store.all;
    addTearDown(() => store.all = previousAll);
    store.all = movies;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: HourTvMobileHome(
            movies: movies,
            allContent: movies,
            store: ContentStore.instance,
            onOpen: (_) {},
            onSearch: () {},
            onProfile: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('VER MÁS  ›'), findsWidgets);
    await tester.tap(find.text('VER MÁS  ›').first);
    await tester.pumpAndSettle();

    expect(find.byType(HourTvMobileRowPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
