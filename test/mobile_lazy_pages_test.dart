import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/services/content_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ContentStore.instance.resetForTesting();
  });

  testWidgets(
    'destinos moviles se construyen perezosamente solo al visitarlos y se conservan',
    (tester) async {
      int homeBuilds = 0;
      int searchBuilds = 0;
      int tvBuilds = 0;
      int libraryBuilds = 0;
      int profileBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HourTvMobileShell(
            destinationBuilders: {
              HourTvMobileDestination.home: (context) {
                homeBuilds++;
                return const Center(child: Text('Home Destination'));
              },
              HourTvMobileDestination.search: (context) {
                searchBuilds++;
                return const Center(child: Text('Search Destination'));
              },
              HourTvMobileDestination.live: (context) {
                tvBuilds++;
                return const Center(child: Text('Live Destination'));
              },
              HourTvMobileDestination.library: (context) {
                libraryBuilds++;
                return const Center(child: Text('Library Destination'));
              },
              HourTvMobileDestination.profile: (context) {
                profileBuilds++;
                return const Center(child: Text('Profile Destination'));
              },
            },
          ),
        ),
      );
      await tester.pump();

      // 1. Inicialmente solo Home se construye.
      expect(homeBuilds, 1);
      expect(searchBuilds, 0);
      expect(tvBuilds, 0);
      expect(libraryBuilds, 0);
      expect(profileBuilds, 0);

      // 2. Visitar Buscar lo construye exactamente una vez.
      await tester.tap(find.text('BUSCAR'));
      await tester.pumpAndSettle();

      expect(homeBuilds, 1);
      expect(searchBuilds, 1);
      expect(tvBuilds, 0);
      expect(libraryBuilds, 0);
      expect(profileBuilds, 0);
      expect(find.text('Search Destination'), findsOneWidget);

      // 3. Volver a Inicio y regresar a Buscar conserva el estado y no reconstruye la raiz.
      await tester.tap(find.text('INICIO'));
      await tester.pumpAndSettle();

      expect(homeBuilds, 1);
      expect(searchBuilds, 1);

      await tester.tap(find.text('BUSCAR'));
      await tester.pumpAndSettle();

      expect(homeBuilds, 1);
      expect(searchBuilds, 1);
      expect(tvBuilds, 0);
      expect(libraryBuilds, 0);
      expect(profileBuilds, 0);

      // 4. Cambios de progreso no recrean Buscar ni TV.
      await ContentStore.instance.updatePlaybackProgress(
        Channel(
          name: 'Pelicula Test',
          url: 'http://test/stream.mp4',
          forcedType: 'movie',
        ),
        0.5,
      );
      await tester.pump();

      expect(searchBuilds, 1);
      expect(tvBuilds, 0);
    },
  );

  testWidgets(
    'shell por defecto no monta widgets de otros destinos hasta que sean visitados',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HourTvMobileShell(),
        ),
      );
      await tester.pump();

      expect(find.byType(HourTvMobileHome), findsOneWidget);
      expect(find.byType(HourTvMobileSearch), findsNothing);
      expect(find.byType(HourTvMobileLibrary), findsNothing);
      expect(find.byType(HourTvMobileProfile), findsNothing);

      // Al navegar a Buscar, se monta Buscar
      await tester.tap(find.text('BUSCAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HourTvMobileSearch), findsOneWidget);
      expect(find.byType(HourTvMobileLibrary), findsNothing);
      expect(find.byType(HourTvMobileProfile), findsNothing);

      // Volver a Inicio mantiene Buscar montado (offstage)
      await tester.tap(find.text('INICIO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HourTvMobileHome), findsOneWidget);
      // Fuera de pantalla (offstage: true)
      expect(find.byType(HourTvMobileSearch), findsNothing);
      // Pero sigue conservado en el arbol (skipOffstage: false)
      expect(
        find.byType(HourTvMobileSearch, skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}
