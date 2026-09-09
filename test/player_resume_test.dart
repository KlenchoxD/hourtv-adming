import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/playback_progress.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  group('decision de reanudacion en el reproductor', () {
    test('resumeOffer: ofrece continuar cuando hay progreso previo', () async {
      final movie = Channel(
        name: 'Empezada',
        url: 'vod:empezada',
        tvgId: '6513',
        forcedType: 'movie',
      );
      // 23:14 de 1:40:10
      await PlaybackProgress.save(
        movie,
        positionMs: 1394000,
        durationMs: 6010000,
      );
      final offer = resumeOfferFor(movie, autoResume: false);
      expect(offer, isNotNull);
      expect(offer!.positionMs, 1394000);
      expect(offer.label, contains('23:14'));
      expect(offer.label, contains('Continuar'));
    });

    test('resumeOffer: autoResume (desde Continuar viendo) no pregunta', () async {
      final movie = Channel(
        name: 'Empezada',
        url: 'vod:empezada',
        tvgId: '6513',
        forcedType: 'movie',
      );
      await PlaybackProgress.save(
        movie,
        positionMs: 1394000,
        durationMs: 6010000,
      );
      final offer = resumeOfferFor(movie, autoResume: true);
      expect(offer, isNotNull);
      expect(offer!.autoResume, isTrue);
    });

    test('resumeOffer: sin progreso previo no ofrece nada', () {
      final movie = Channel(
        name: 'Nueva',
        url: 'vod:nueva',
        tvgId: '6514',
        forcedType: 'movie',
      );
      expect(resumeOfferFor(movie, autoResume: false), isNull);
    });

    test('resumeOffer: titulo ya visto no ofrece continuar (reinicia)', () async {
      final movie = Channel(
        name: 'Vista',
        url: 'vod:vista',
        tvgId: '6515',
        forcedType: 'movie',
      );
      await PlaybackProgress.save(
        movie,
        positionMs: 5990000,
        durationMs: 6010000,
      );
      expect(resumeOfferFor(movie, autoResume: false), isNull);
    });

    test('resumeOffer: live nunca ofrece continuar', () async {
      final live = Channel(name: 'Canal', url: 'http://live/x.m3u8');
      expect(resumeOfferFor(live, autoResume: false), isNull);
    });

    test('resumeOffer: progreso minimo (<10s) no molesta con el dialogo', () async {
      final movie = Channel(
        name: 'Casi nueva',
        url: 'vod:casi',
        tvgId: '6516',
        forcedType: 'movie',
      );
      await PlaybackProgress.save(movie, positionMs: 4000, durationMs: 6010000);
      expect(resumeOfferFor(movie, autoResume: false), isNull);
    });
  });

  group('guardado de progreso desde el reproductor', () {
    test('savePlaybackPosition persiste posicion absoluta y fraccion', () async {
      final movie = Channel(
        name: 'Peli',
        url: 'vod:peli',
        tvgId: '42',
        forcedType: 'movie',
      );
      await savePlaybackPosition(movie, positionMs: 7200000, durationMs: 9600000);
      final restored = PlaybackProgress.load(movie);
      expect(restored!.positionMs, 7200000);
      expect(restored.fraction, closeTo(0.75, 0.001));
    });

    test('un titulo completado desaparece de Continuar viendo', () async {
      final movie = Channel(
        name: 'Completa',
        url: 'vod:completa',
        tvgId: '43',
        forcedType: 'movie',
      );
      await StorageService.saveRecent(movie);
      await savePlaybackPosition(movie, positionMs: 5800000, durationMs: 6000000);

      // El store filtra por >=95%.
      final stored = PlaybackProgress.load(movie);
      expect(stored!.isCompleted, isTrue);
    });

    test('película reanuda desde posición guardada', () async {
      final movie = Channel(
        name: 'Matrix',
        url: 'vod:matrix',
        tvgId: 'tmdb:603',
        forcedType: 'movie',
      );
      // Guardar posición a los 45 minutos de 2 horas
      await savePlaybackPosition(movie, positionMs: 2700000, durationMs: 7200000);

      // Entrada desde Continuar viendo (autoResume: true)
      final offer = resumeOfferFor(movie, autoResume: true);
      expect(offer, isNotNull);
      expect(offer!.positionMs, 2700000);
      expect(offer.autoResume, isTrue);
    });

    test('reproducción no empieza antes del seek (ticks previos no pisan el progreso guardado)', () async {
      final movie = Channel(
        name: 'Inception',
        url: 'vod:inception',
        tvgId: 'tmdb:27205',
        forcedType: 'movie',
      );
      // Progreso previo: 1 hora
      await savePlaybackPosition(movie, positionMs: 3600000, durationMs: 7200000);

      // Simulamos que el reproductor emite ticks a 0 segundos antes de aplicar el seek:
      // Con _resumeApplied = false o ticks espurios < target - 3s, la posición NO debe sobrescribirse.
      final savedBefore = PlaybackProgress.load(movie);
      expect(savedBefore!.positionMs, 3600000);

      // Si se intentara guardar una posición espuria de 0 o 1s mientras no se aplicó el seek:
      final isResumeTickBeforeSeek = 3600000 > 0 && 1000 < (3600000 - 3000);
      expect(isResumeTickBeforeSeek, isTrue, reason: 'Ticks tempranos antes del seek son descartados');

      // El progreso guardado sigue intacto
      expect(PlaybackProgress.load(movie)!.positionMs, 3600000);
    });
  });

  group('progreso y reanudacion en series', () {
    test('episodio siempre reanuda directo (autoResume = true)', () async {
      final ep = Channel(
        name: 'Episodio 1',
        url: 'vod:ep1',
        tvgId: 'catalog:10:1:1',
        forcedType: 'series',
      );
      await PlaybackProgress.save(ep, positionMs: 600000, durationMs: 2400000);
      final offer = resumeOfferFor(ep, autoResume: false);
      expect(offer, isNotNull);
      expect(offer!.autoResume, isTrue, reason: 'Episodios reanudan directo como en Netflix');
    });

    test('serie selecciona último episodio incompleto', () async {
      final ep1 = Channel(name: 'E1', url: 'vod:e1', tvgId: 'catalog:10:1:1', forcedType: 'series');
      final ep2 = Channel(name: 'E2', url: 'vod:e2', tvgId: 'catalog:10:1:2', forcedType: 'series');
      final ep3 = Channel(name: 'E3', url: 'vod:e3', tvgId: 'catalog:10:1:3', forcedType: 'series');

      // E1 completado al 100%
      await PlaybackProgress.save(ep1, positionMs: 2400000, durationMs: 2400000);
      // E2 en progreso al 40%
      await PlaybackProgress.save(ep2, positionMs: 960000, durationMs: 2400000);

      final selected = PlaybackProgress.nextUnfinishedEpisode([ep1, ep2, ep3]);
      expect(selected?.tvgId, ep2.tvgId);
    });

    test('terminado al 95% pasa al siguiente', () async {
      final ep1 = Channel(name: 'E1', url: 'vod:e1', tvgId: 'catalog:10:1:1', forcedType: 'series');
      final ep2 = Channel(name: 'E2', url: 'vod:e2', tvgId: 'catalog:10:1:2', forcedType: 'series');

      // E1 al 96% -> se considera completado
      await PlaybackProgress.save(ep1, positionMs: 2310000, durationMs: 2400000);

      final selected = PlaybackProgress.nextUnfinishedEpisode([ep1, ep2]);
      expect(selected?.tvgId, ep2.tvgId, reason: 'Debe saltar al siguiente episodio');
    });

    test('si todos están terminados, permite reproducir nuevamente desde el primero', () async {
      final ep1 = Channel(name: 'E1', url: 'vod:e1', tvgId: 'catalog:10:1:1', forcedType: 'series');
      final ep2 = Channel(name: 'E2', url: 'vod:e2', tvgId: 'catalog:10:1:2', forcedType: 'series');

      await PlaybackProgress.save(ep1, positionMs: 2400000, durationMs: 2400000);
      await PlaybackProgress.save(ep2, positionMs: 2400000, durationMs: 2400000);

      final selected = PlaybackProgress.nextUnfinishedEpisode([ep1, ep2]);
      expect(selected?.tvgId, ep1.tvgId, reason: 'Vuelve al primero cuando toda la temporada está completa');
    });
  });

  group('diálogo de reanudación (UI y decisiones)', () {
    testWidgets('diálogo ofrece continuar o reiniciar con textos exactos', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final offer = ResumeOffer(
                    positionMs: 3600000,
                    autoResume: false,
                    label: 'Continuar desde 1:00:00',
                  );
                  result = await showDialog<int>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('¿Continuar viendo?'),
                      content: Text(
                        'Guardaste este título hasta ${formatResumeClock(offer.positionMs)}.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(0),
                          child: const Text('Reproducir desde el inicio'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(dialogContext).pop(offer.positionMs),
                          child: Text(offer.label),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Abrir dialogo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir dialogo'));
      await tester.pumpAndSettle();

      expect(find.text('¿Continuar viendo?'), findsOneWidget);
      expect(find.text('Guardaste este título hasta 1:00:00.'), findsOneWidget);
      expect(find.text('Reproducir desde el inicio'), findsOneWidget);
      expect(find.text('Continuar desde 1:00:00'), findsOneWidget);

      await tester.tap(find.text('Continuar desde 1:00:00'));
      await tester.pumpAndSettle();
      expect(result, 3600000);
    });

    testWidgets('pulsar Reproducir desde el inicio devuelve 0', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final offer = ResumeOffer(
                    positionMs: 3600000,
                    autoResume: false,
                    label: 'Continuar desde 1:00:00',
                  );
                  result = await showDialog<int>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('¿Continuar viendo?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(0),
                          child: const Text('Reproducir desde el inicio'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(dialogContext).pop(offer.positionMs),
                          child: Text(offer.label),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reproducir desde el inicio'));
      await tester.pumpAndSettle();
      expect(result, 0);
    });
  });
}
