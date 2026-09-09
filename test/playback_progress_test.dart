import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/playback_progress.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  group('identidad estable del contenido', () {
    test('pelicula usa el id de catalogo, no la URL del servidor', () {
      final movie = Channel(
        name: 'Viuda Negra',
        url: 'https://barmonrey.com/player/A/',
        tvgId: '6513',
        forcedType: 'movie',
      );
      expect(
        PlaybackProgress.contentKey(movie),
        'movie:6513',
        reason: 'El id de catalogo es estable aunque cambie el mirror',
      );
    });

    test('pelicula sin id cae a titulo normalizado, estable entre mirrors', () {
      final a = Channel(
        name: 'Orgullo y prejuicio',
        url: 'https://servidor-a/movie.mkv',
        forcedType: 'movie',
      );
      final b = Channel(
        name: 'Orgullo y prejuicio',
        url: 'https://servidor-b/otro.mp4',
        forcedType: 'movie',
      );
      expect(PlaybackProgress.contentKey(a), PlaybackProgress.contentKey(b));
      expect(PlaybackProgress.contentKey(a), isNot(a.url));
    });

    test('episodio usa serie+temporada+episodio del tvgId', () {
      final ep = Channel(
        name: 'Capítulo 1',
        url: 'https://voe.sx/e/abc',
        tvgId: 'catalog:12:1:1',
        forcedType: 'series',
      );
      expect(PlaybackProgress.contentKey(ep), 'series:catalog:12:1:1');
    });

    test('episodio de serie plana sintetica tambien tiene identidad estable', () {
      // Ruta 6 de hourTvResolveSeries: canal de lista con forcedType series
      // y tvgId propio; la serie sintetica conserva el tvgId del canal.
      final ep = Channel(
        name: 'Novela 1x02',
        url: 'https://cdn.example/serie/1x02.mp4',
        tvgId: 'catalog:77:1:2',
        forcedType: 'series',
      );
      expect(PlaybackProgress.contentKey(ep), 'series:catalog:77:1:2');
    });

    test('episodio sin tvgId cae a titulo de serie+episodio normalizado', () {
      final a = Channel(
        name: 'La reina 1x02',
        url: 'https://a.example/e1',
        group: 'T1',
        forcedType: 'series',
      );
      final b = a.copyWith(url: 'https://b.example/e1-mirror');
      expect(PlaybackProgress.contentKey(a), PlaybackProgress.contentKey(b));
    });
  });

  group('guardar y restaurar posicion absoluta', () {
    test('pelicula guarda posicion/duracion/fraccion y restaura seek', () async {
      final movie = Channel(
        name: 'Empezada',
        url: 'vod:empezada',
        tvgId: '6513',
        forcedType: 'movie',
      );
      await PlaybackProgress.save(movie, positionMs: 1394000, durationMs: 6010000);

      final restored = PlaybackProgress.load(movie);
      expect(restored, isNotNull);
      expect(restored!.positionMs, 1394000);
      expect(restored.durationMs, 6010000);
      expect(restored.fraction, closeTo(0.232, 0.001));
    });

    test('episodio reanuda independientemente de otro episodio', () async {
      final e1 = Channel(
        name: 'Cap 1',
        url: 'https://a/e1',
        tvgId: 'catalog:5:1:1',
        forcedType: 'series',
      );
      final e2 = Channel(
        name: 'Cap 2',
        url: 'https://a/e2',
        tvgId: 'catalog:5:1:2',
        forcedType: 'series',
      );
      await PlaybackProgress.save(e1, positionMs: 600000, durationMs: 2700000);
      await PlaybackProgress.save(e2, positionMs: 120000, durationMs: 2700000);

      expect(PlaybackProgress.load(e1)!.positionMs, 600000);
      expect(PlaybackProgress.load(e2)!.positionMs, 120000);
    });

    test('dos episodios no comparten progreso (claves distintas)', () {
      final e1 = Channel(
        name: 'Cap 1',
        url: 'x',
        tvgId: 'catalog:5:1:1',
        forcedType: 'series',
      );
      final e2 = Channel(
        name: 'Cap 2',
        url: 'x',
        tvgId: 'catalog:5:1:2',
        forcedType: 'series',
      );
      expect(
        PlaybackProgress.contentKey(e1),
        isNot(PlaybackProgress.contentKey(e2)),
      );
    });

    test('cambiar de servidor/mirror no pierde el progreso', () async {
      final original = Channel(
        name: 'Empezada',
        url: 'https://barmonrey.com/player/A/',
        tvgId: '6513',
        forcedType: 'movie',
        servers: const [
          ChannelServer(name: 'Barmonrey', url: 'https://barmonrey.com/player/A/'),
          ChannelServer(name: 'VOE', url: 'https://voe.sx/e/abc'),
        ],
      );
      await PlaybackProgress.save(original, positionMs: 900000, durationMs: 6000000);

      // El usuario cambia al mirror VOE: mismo titulo, otra URL.
      final conMirror = original.copyWith(url: 'https://voe.sx/e/abc');
      expect(
        PlaybackProgress.load(conMirror)!.positionMs,
        900000,
        reason: 'La identidad es el contenido, no la URL del servidor',
      );
    });

    test('contenido terminado (>=95%) se marca como visto', () async {
      final movie = Channel(
        name: 'Terminada',
        url: 'vod:terminada',
        tvgId: '99',
        forcedType: 'movie',
      );
      await PlaybackProgress.save(movie, positionMs: 5900000, durationMs: 6000000);
      final restored = PlaybackProgress.load(movie);
      expect(restored, isNotNull);
      expect(restored!.isCompleted, isTrue);
      expect(restored.resumePositionMs, Duration.zero.inMilliseconds,
          reason: 'Un titulo visto reanuda desde el inicio si se reabre');
    });
  });

  group('persistencia por perfil', () {
    test('el progreso es independiente entre perfiles', () async {
      final movie = Channel(
        name: 'Peli',
        url: 'vod:peli',
        tvgId: '42',
        forcedType: 'movie',
      );

      await StorageService.setActiveProfile('Kleiner');
      await PlaybackProgress.save(movie, positionMs: 100000, durationMs: 6000000);

      await StorageService.setActiveProfile('Invitado');
      final guestProgress = PlaybackProgress.load(movie);
      expect(
        guestProgress,
        isNull,
        reason: 'Invitado no vio nada: sin progreso guardado',
      );

      await PlaybackProgress.save(movie, positionMs: 300000, durationMs: 6000000);
      expect(PlaybackProgress.load(movie)!.positionMs, 300000);

      await StorageService.setActiveProfile('Kleiner');
      expect(
        PlaybackProgress.load(movie)!.positionMs,
        100000,
        reason: 'Cada perfil conserva su propio avance',
      );
    });
  });

  group('retrocompatibilidad con progressFraction', () {
    test('datos viejos con solo progressFraction siguen funcionando', () async {
      final movie = Channel(
        name: 'Vieja',
        url: 'vod:vieja',
        tvgId: '777',
        forcedType: 'movie',
        duration: '100',
      );
      // Como lo guardaba la version anterior: fraccion sobre recientes.
      await StorageService.saveRecent(movie);
      await StorageService.updateRecentProgress('vod:vieja', 0.25);

      final restored = PlaybackProgress.load(movie);
      expect(restored, isNotNull,
          reason: 'El usuario viejo debe poder reanudar su pelicula');
      expect(restored!.fraction, closeTo(0.25, 0.01));
      // Con la duracion conocida del catalogo (string "100" = minutos) se
      // reconstruye la posicion absoluta.
      expect(restored.resumePositionMs, 1500000);
    });
  });

  group('siguiente episodio de una serie', () {
    test('encuentra el proximo episodio por tvgId', () {
      final episodes = [
        Channel(name: 'C1', url: 'a', tvgId: 'catalog:5:1:1', forcedType: 'series'),
        Channel(name: 'C2', url: 'b', tvgId: 'catalog:5:1:2', forcedType: 'series'),
        Channel(name: 'C3', url: 'c', tvgId: 'catalog:5:1:3', forcedType: 'series'),
      ];
      final next = PlaybackProgress.nextEpisode(
        episodes[1],
        episodes,
      );
      expect(next?.tvgId, 'catalog:5:1:3');
    });

    test('devuelve null en el ultimo episodio de la temporada', () {
      final episodes = [
        Channel(name: 'C1', url: 'a', tvgId: 'catalog:5:1:1', forcedType: 'series'),
      ];
      expect(PlaybackProgress.nextEpisode(episodes[0], episodes), isNull);
    });
  });

  group('concurrencia y guardados consecutivos sin carreras', () {
    test('ninguna carrera evidente entre guardados consecutivos (escrituras paralelas no se pisan)', () async {
      final channels = List.generate(
        15,
        (i) => Channel(
          name: 'Peli $i',
          url: 'vod:peli_$i',
          tvgId: 'multi_$i',
          forcedType: 'movie',
        ),
      );

      // Lanzar 15 guardados paralelos concurrentes
      await Future.wait(
        channels.map(
          (c) => PlaybackProgress.save(
            c,
            positionMs: 50000 + channels.indexOf(c) * 1000,
            durationMs: 120000,
          ),
        ),
      );

      // Todos deben estar persistidos con su valor correcto en memoria y lectura
      for (var i = 0; i < channels.length; i++) {
        final restored = PlaybackProgress.load(channels[i]);
        expect(restored, isNotNull, reason: 'Peli $i debe existir');
        expect(restored!.positionMs, 50000 + i * 1000);
      }
    });

    test('salida rápida persiste (guardar e inmediatamente consultar no pierde datos)', () async {
      final fastChannel = Channel(
        name: 'Fast Exit',
        url: 'vod:fast',
        tvgId: 'fast_99',
        forcedType: 'movie',
      );

      // Sin await explícito o consulta sincrónica inmediata
      final saveFuture = PlaybackProgress.save(
        fastChannel,
        positionMs: 88888,
        durationMs: 200000,
      );

      // Lectura inmediata síncrona
      final syncRead = PlaybackProgress.load(fastChannel);
      expect(syncRead, isNotNull);
      expect(syncRead!.positionMs, 88888);

      await saveFuture;
      final afterAwaitRead = PlaybackProgress.load(fastChannel);
      expect(afterAwaitRead!.positionMs, 88888);
    });

    test('dos episodios de serie con nombre descriptivo y mismo grupo no comparten progreso', () {
      final ep1 = Channel(
        name: 'Capítulo 1 - El inicio',
        url: 'http://cdn/1',
        group: 'Temporada 1',
        forcedType: 'series',
      );
      final ep2 = Channel(
        name: 'Capítulo 2 - La revelación',
        url: 'http://cdn/2',
        group: 'Temporada 1',
        forcedType: 'series',
      );

      expect(
        PlaybackProgress.contentKey(ep1),
        isNot(PlaybackProgress.contentKey(ep2)),
      );
    });
  });
}
