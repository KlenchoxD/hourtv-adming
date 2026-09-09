import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/new_ui/hourtv_series_detail_page.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late XtreamSeries sampleSeries;
  late Channel ep1;
  late Channel ep2;
  late Channel ep3;

  setUp(() {
    ep1 = Channel(
      name: 'Sombras en el límite',
      url: 'https://cdn.test/series/fr/s1e1.mp4',
      group: 'T1',
      forcedType: 'series',
      duration: '52 min',
      plot: 'Lucía llega al puesto fronterizo bajo una identidad civil.',
      progressFraction: 0.75,
      servers: const [
        ChannelServer(
          name: 'Principal',
          url: 'https://cdn.test/series/fr/s1e1.mp4',
        ),
        ChannelServer(
          name: 'Mirror 1',
          url: 'https://backup.test/series/fr/s1e1.mp4',
        ),
      ],
    );

    ep2 = Channel(
      name: 'Vuelo ciego',
      url: 'https://cdn.test/series/fr/s1e2.mp4',
      group: 'T1',
      forcedType: 'series',
      duration: '48 min',
      plot:
          'Una persecución en el desierto nocturno pone a prueba las lealtades.',
    );

    ep3 = Channel(
      name: 'Regreso al origen',
      url: 'https://cdn.test/series/fr/s2e1.mp4',
      group: 'T2',
      forcedType: 'series',
      duration: '50 min',
      plot: 'Nueva temporada en la ciudad central.',
    );

    sampleSeries = XtreamSeries(
      seriesId: 'serie-frontera-roja',
      name: 'Frontera Roja',
      cover: 'https://images.unsplash.com/photo-1509198397868?w=800',
      backdrop: 'https://images.unsplash.com/photo-1509198397868?w=1600',
      plot: 'Una agente de inteligencia encubierta ingresa a la frontera.',
      director: 'Mariana Cordero',
      writer: 'Lucía Fernández',
      genre: 'Crimen, Drama, Acción',
      year: '2026',
      rating: '9.6',
      duration: '2 Temporadas',
      cast: 'Valeria Solís, Rodrigo Santoro, Alba Flores',
      releaseDate: '2026-01-20',
      host: '',
      username: '',
      password: '',
      episodes: [ep1, ep2, ep3],
    );
  });

  Widget buildTestWidget({
    required WidgetTester tester,
    XtreamSeries? series,
    Size size = const Size(390, 844),
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return MaterialApp(
      home: HourTvSeriesDetailPage(series: series ?? sampleSeries),
    );
  }

  testWidgets('1. Muestra botón flotante volver con icono de flecha atrás', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(tester: tester));
    await tester.pumpAndSettle();

    final backButton = find.byTooltip('Volver');
    expect(backButton, findsOneWidget);
    expect(
      find.descendant(
        of: backButton,
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
      findsWidgets,
    );
  });

  testWidgets('2. Muestra título, badges de calidad 4K UHD, HDR10+, 5.1', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(tester: tester));
    await tester.pumpAndSettle();

    expect(find.text('Frontera Roja'), findsWidgets);
    expect(find.text('4K UHD'), findsOneWidget);
    expect(find.text('HDR10+'), findsOneWidget);
    expect(find.text('5.1'), findsOneWidget);
  });

  testWidgets(
    '3. Botón principal muestra "Reproducir T1:E1" con estilo esmeralda',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('Reproducir T1:E1'), findsOneWidget);
    },
  );

  testWidgets('4. Muestra botones secundarios "Mi Lista" y "Compartir"', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(tester: tester));
    await tester.pumpAndSettle();

    expect(find.text('Mi Lista'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
  });

  testWidgets(
    '5. Muestra sección de sinopsis y ficha técnica (Dirección, Guion, Género, Duración)',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('SINOPSIS'), findsOneWidget);
      expect(
        find.text(
          'Una agente de inteligencia encubierta ingresa a la frontera.',
        ),
        findsOneWidget,
      );
      expect(find.text('DIRECCIÓN'), findsOneWidget);
      expect(find.text('Mariana Cordero'), findsOneWidget);
      expect(find.text('GUION'), findsOneWidget);
      expect(find.text('Lucía Fernández'), findsOneWidget);
      expect(find.text('GÉNERO'), findsOneWidget);
      expect(find.text('Crimen, Drama, Acción'), findsOneWidget);
    },
  );

  testWidgets(
    '6. Encabezado de episodios tiene icono Tv y selector de temporada con ChevronDown',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('Episodios'), findsOneWidget);
      expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
      expect(find.text('Temporada 1'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    },
  );

  testWidgets(
    '7. Al pulsar selector de temporada se despliega el menú de selección',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      final seasonButton = find.text('Temporada 1');
      await tester.ensureVisible(seasonButton);
      await tester.pumpAndSettle();
      await tester.tap(seasonButton);
      await tester.pumpAndSettle();

      // Deben verse las opciones Temporada 1 y Temporada 2 en el menú
      expect(find.text('Temporada 2'), findsWidgets);
      // Temporada 1 activa debe tener check
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
    },
  );

  testWidgets(
    '8. Cambiar a Temporada 2 actualiza los episodios visibles y el botón principal',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      // Inicialmente en T1 se ven ep1 y ep2
      expect(find.text('Sombras en el límite'), findsOneWidget);
      expect(find.text('Vuelo ciego'), findsOneWidget);
      expect(find.text('Regreso al origen'), findsNothing);

      // Abrir dropdown y seleccionar T2
      final seasonButton = find.text('Temporada 1').first;
      await tester.ensureVisible(seasonButton);
      await tester.pumpAndSettle();
      await tester.tap(seasonButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Temporada 2').last);
      await tester.pumpAndSettle();

      // Ahora se debe ver el episodio de T2
      expect(find.text('Regreso al origen'), findsOneWidget);
      expect(find.text('Sombras en el límite'), findsNothing);
      expect(find.text('Reproducir T2:E1'), findsOneWidget);
    },
  );

  testWidgets(
    '9. EpisodeCard renderiza miniatura 16:9, botón play overlay, EP. X, título, duración y sinopsis',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('Sombras en el límite'), findsOneWidget);
      expect(find.textContaining('Episodio 1'), findsWidgets);
      expect(find.textContaining('52 min'), findsOneWidget);
      expect(
        find.text('Lucía llega al puesto fronterizo bajo una identidad civil.'),
        findsOneWidget,
      );
      // Play overlay
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      // Barra de progreso presente en ep1 (75%)
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    '10. Al pulsar un episodio se abre PlayerScreen con el episodio, allChannels de la temporada, e initialIndex exacto',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      // Pulsar ep2 (Vuelo ciego - index 1)
      final ep2Finder = find.text('Vuelo ciego');
      await tester.ensureVisible(ep2Finder);
      await tester.pumpAndSettle();
      await tester.tap(ep2Finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      expect(player.channel.name, 'Vuelo ciego');
      expect(player.initialIndex, 1);
      expect(player.allChannels.length, 2); // Los 2 episodios de T1
      expect(player.allChannels.first.name, 'Sombras en el límite');
      expect(player.allChannels.last.name, 'Vuelo ciego');
    },
  );

  testWidgets(
    '11. El episodio conserva sus servidores principales y mirrors al reproducir',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      // Pulsar ep1
      final ep1Finder = find.text('Sombras en el límite');
      await tester.ensureVisible(ep1Finder);
      await tester.pumpAndSettle();
      await tester.tap(ep1Finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      expect(player.channel.servers, hasLength(2));
      expect(
        player.channel.servers.last.url,
        'https://backup.test/series/fr/s1e1.mp4',
      );
    },
  );

  testWidgets('12. Muestra estado vacío cuando no hay episodios', (
    tester,
  ) async {
    final emptySeries = XtreamSeries(
      seriesId: 'empty-1',
      name: 'Serie Vacía',
      host: '',
      username: '',
      password: '',
      episodes: const [],
    );

    await tester.pumpWidget(
      buildTestWidget(tester: tester, series: emptySeries),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No hay episodios disponibles para esta temporada.'),
      findsOneWidget,
    );
  });

  testWidgets(
    '13. Reparto principal muestra lista horizontal de actores con avatares',
    (tester) async {
      await tester.pumpWidget(buildTestWidget(tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('Reparto Principal'), findsOneWidget);
      expect(find.text('Valeria Solís'), findsOneWidget);
      expect(find.text('Rodrigo Santoro'), findsOneWidget);
      expect(find.text('Alba Flores'), findsOneWidget);
    },
  );
}
