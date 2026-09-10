import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  test(
    'continueWatching solo incluye VOD empezado y no terminado',
    () async {
      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);

      final movie = Channel(
        name: 'Empezada',
        url: 'vod:empezada',
        forcedType: 'movie',
        duration: '120',
      );
      final finished = Channel(
        name: 'Terminada',
        url: 'vod:terminada',
        forcedType: 'movie',
      );
      final untouched = Channel(
        name: 'Sin ver',
        url: 'vod:sinver',
        forcedType: 'movie',
      );
      final live = Channel(name: 'Canal en vivo', url: 'live:1');
      store.all = [movie, finished, untouched, live];

      await StorageService.saveRecent(movie);
      await StorageService.saveRecent(finished);
      await StorageService.saveRecent(live);

      await store.updatePlaybackProgress(movie, 0.4);
      await store.updatePlaybackProgress(finished, 0.99);
      await store.updatePlaybackProgress(live, 0.5);

      expect(
        store.continueWatching.map((item) => item.url),
        ['vod:empezada'],
      );
      expect(store.history.map((item) => item.url), [
        'live:1',
        'vod:terminada',
        'vod:empezada',
      ]);
    },
  );

  test(
    'updatePlaybackProgress con notify:false no avisa a los listeners',
    () async {
      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);

      final movie = Channel(
        name: 'En progreso',
        url: 'vod:progreso',
        forcedType: 'movie',
      );
      store.all = [movie];
      await StorageService.saveRecent(movie);

      var notifications = 0;
      void listener() => notifications++;
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));

      // Ticks periodicos durante la reproduccion: no deben reconstruir toda
      // la app de fondo mientras el usuario esta viendo un video.
      await store.updatePlaybackProgress(movie, 0.2, notify: false);
      await store.updatePlaybackProgress(movie, 0.4, notify: false);
      expect(notifications, 0);
      expect(movie.progressFraction, 0.4);

      // Guardado final al salir del reproductor: este si debe notificar.
      await store.updatePlaybackProgress(movie, 0.5);
      expect(notifications, 1);
    },
  );

  testWidgets(
    'tarjetas de Continuar viendo usan HourTvPosterCard con el mismo contrato de ancho y aspect ratio que el catalogo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);

      final movie = Channel(
        name: 'Interestelar',
        url: 'http://stream/inter.mp4',
        forcedType: 'movie',
        duration: '100 min',
        backdrop: 'http://img/inter_back.jpg',
        logo: 'http://img/inter_logo.jpg',
      );
      store.all = [movie];
      await StorageService.saveRecent(movie);
      await store.updatePlaybackProgress(movie, 0.6);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileHome(
              store: store,
              allContent: [movie],
              movies: [movie],
              onOpen: (_) {},
              onOpenContinue: (_) {},
              onProfile: () {},
              onSearch: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTINUAR VIENDO'), findsOneWidget);

      // Debe usar HourTvPosterCard en vez de una tarjeta ancha incompatible
      final continueCardFinder = find.ancestor(
        of: find.text('Interestelar'),
        matching: find.byType(HourTvPosterCard),
      );
      expect(continueCardFinder, findsWidgets);

      final posterCard = tester.widget<HourTvPosterCard>(continueCardFinder.first);
      expect(posterCard.width, 120);
      expect(posterCard.progress, closeTo(0.6, 0.001));

      // Debe incluir una barra de progreso delgada
      final progressFinder = find.descendant(
        of: continueCardFinder,
        matching: find.byType(LinearProgressIndicator),
      );
      expect(progressFinder, findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(indicator.minHeight, 3);
      expect(indicator.value, closeTo(0.6, 0.001));

      // AspectRatio del poster debe ser 120 / 178
      final aspectFinder = find.descendant(
        of: continueCardFinder,
        matching: find.byType(AspectRatio),
      );
      expect(aspectFinder, findsWidgets);
      final aspect = tester.widget<AspectRatio>(aspectFinder.first);
      expect(aspect.aspectRatio, closeTo(120 / 178, 0.001));
    },
  );

  testWidgets(
    'muestra tiempo restante real solo cuando la duracion es calculable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);

      final calculable = Channel(
        name: 'Peli Calculable',
        url: 'http://stream/calc.mp4',
        forcedType: 'movie',
        duration: '100 min',
      );
      final sinDuracion = Channel(
        name: 'Peli Sin Duracion',
        url: 'http://stream/sin_dur.mp4',
        forcedType: 'movie',
      );

      store.all = [calculable, sinDuracion];
      await StorageService.saveRecent(calculable);
      await StorageService.saveRecent(sinDuracion);
      await store.updatePlaybackProgress(calculable, 0.6); // 100 * (1 - 0.6) = 40 min
      await store.updatePlaybackProgress(sinDuracion, 0.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileHome(
              store: store,
              allContent: [calculable, sinDuracion],
              movies: [calculable, sinDuracion],
              onOpen: (_) {},
              onProfile: () {},
              onSearch: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quedan 40 min calculable
      expect(find.text('Quedan 40 min'), findsOneWidget);

      // Para la que no tiene duracion no se inventa tiempo restante
      final continueCards = find.byType(HourTvPosterCard);
      expect(continueCards, findsWidgets);
      expect(find.textContaining('Quedan'), findsOneWidget);
    },
  );

  testWidgets(
    'al pulsar la tarjeta de Continuar viendo se invoca onOpenContinue directamente',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = ContentStore.instance;
      final previous = store.all;
      addTearDown(() => store.all = previous);

      final movie = Channel(
        name: 'Reanudar Directo',
        url: 'http://stream/directo.mp4',
        forcedType: 'movie',
        duration: '90',
      );
      store.all = [movie];
      await StorageService.saveRecent(movie);
      await store.updatePlaybackProgress(movie, 0.5);

      Channel? openedNormal;
      Channel? openedContinue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileHome(
              store: store,
              allContent: [movie],
              movies: [movie],
              onOpen: (ch) => openedNormal = ch,
              onOpenContinue: (ch) => openedContinue = ch,
              onProfile: () {},
              onSearch: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.ancestor(
        of: find.text('Reanudar Directo'),
        matching: find.byType(HourTvPosterCard),
      );
      await tester.tap(cardFinder.first);
      await tester.pumpAndSettle();

      expect(openedContinue, isNotNull);
      expect(openedContinue!.url, 'http://stream/directo.mp4');
      expect(openedNormal, isNull);
    },
  );
}
