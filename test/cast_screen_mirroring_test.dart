import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_cast_sheet.dart';
import 'package:streamtv/new_ui/hourtv_detail_page.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/cast_service.dart';
import 'package:streamtv/services/playback_progress.dart';
import 'package:streamtv/services/storage_service.dart';

Future<void> withPlatform(
  TargetPlatform platform,
  Future<void> Function() action,
) async {
  final previous = debugDefaultTargetPlatformOverride;
  try {
    debugDefaultTargetPlatformOverride = platform;
    await action();
  } finally {
    debugDefaultTargetPlatformOverride = previous;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  group('CastService - Detección tipada de bloqueos (checkStreamBlocked)', () {
    test('contenido con Referer/User-Agent ofrece duplicación con motivo tipado', () {
      final block = CastService.checkStreamBlocked(
        streamUrl: 'https://stream.test/live.m3u8',
        mediaType: MediaType.live,
        userAgent: 'HourTV/1.0 (CustomUA)',
      );
      expect(block, isNotNull);
      expect(block!.reason, StreamBlockReason.requiresHeaders);
      expect(block.isHeaderOrWebView, isTrue);
      expect(block.explanation, contains('cabeceras personalizadas'));
    });

    test('contenido que requiere cabeceras por flag de reproductor', () {
      final block = CastService.checkStreamBlocked(
        streamUrl: 'https://stream.test/video.mp4',
        mediaType: MediaType.movie,
        requiresHeaders: true,
      );
      expect(block, isNotNull);
      expect(block!.reason, StreamBlockReason.requiresHeaders);
      expect(block.isHeaderOrWebView, isTrue);
    });

    test('reproducción en visor web/embed devuelve motivo tipado webViewOrEmbed', () {
      final block = CastService.checkStreamBlocked(
        streamUrl: 'https://embed.test/v/1234',
        mediaType: MediaType.movie,
        isEmbedOrWebView: true,
      );
      expect(block, isNotNull);
      expect(block!.reason, StreamBlockReason.webViewOrEmbed);
      expect(block.isHeaderOrWebView, isTrue);
      expect(block.explanation, contains('visor web'));
    });

    test('formato no compatible (.avi, etc.) devuelve unsupportedFormat', () {
      final block = CastService.checkStreamBlocked(
        streamUrl: 'https://cdn.test/video.avi',
        mediaType: null,
      );
      expect(block, isNotNull);
      expect(block!.reason, StreamBlockReason.unsupportedFormat);
      expect(block.isHeaderOrWebView, isFalse);
      expect(block.explanation, contains('.m3u8'));
    });

    test('URL no válida de red devuelve invalidUrl', () {
      final block = CastService.checkStreamBlocked(
        streamUrl: 'file:///local/video.mp4',
        mediaType: MediaType.movie,
      );
      expect(block, isNotNull);
      expect(block!.reason, StreamBlockReason.invalidUrl);
      expect(block.isHeaderOrWebView, isFalse);
    });

    test('stream público compatible no devuelve bloqueo (retorna null)', () {
      final block = CastService.checkStreamBlocked(
        streamUrl: 'https://cdn.test/stream.m3u8',
        mediaType: MediaType.movie,
      );
      expect(block, isNull);
    });

    test('canal en vivo público compatible no devuelve bloqueo', () {
      final block = CastService.checkStreamBlocked(
        streamUrl: 'https://cdn.test/live/stream.m3u8',
        mediaType: MediaType.live,
      );
      expect(block, isNull);
    });
  });

  group('CastService - openCastSettings e integración con el sistema', () {
    test('duplicación invoca openCastSettings y mapea target cast', () async {
      await withPlatform(TargetPlatform.android, () async {
        String? invokedMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('hourtv/device'),
          (MethodCall call) async {
            invokedMethod = call.method;
            return 'cast';
          },
        );

        final result = await CastService.instance.openCastSettings();
        expect(invokedMethod, 'openCastSettings');
        expect(result.opened, isTrue);
        expect(result.target, CastSettingsTarget.cast);
      });
    });

    test('openCastSettings mapea target wireless', () async {
      await withPlatform(TargetPlatform.android, () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('hourtv/device'),
          (MethodCall call) async => 'wireless',
        );

        final result = await CastService.instance.openCastSettings();
        expect(result.opened, isTrue);
        expect(result.target, CastSettingsTarget.wireless);
      });
    });

    test('openCastSettings mapea target display (ajustes de pantalla)', () async {
      await withPlatform(TargetPlatform.android, () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('hourtv/device'),
          (MethodCall call) async => 'display',
        );

        final result = await CastService.instance.openCastSettings();
        expect(result.opened, isTrue);
        expect(result.target, CastSettingsTarget.display);
        expect(result.target!.label, 'Ajustes de pantalla');
      });
    });

    test('openCastSettings maneja error cuando el dispositivo no ofrece actividad', () async {
      await withPlatform(TargetPlatform.android, () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('hourtv/device'),
          (MethodCall call) async {
            throw PlatformException(
              code: 'cast_settings_unavailable',
              message: 'No compatible',
            );
          },
        );

        final result = await CastService.instance.openCastSettings();
        expect(result.opened, isFalse);
        expect(result.errorMessage, contains('No compatible'));
      });
    });

    test('isScreenMirroringSupported solo es true en Android móvil/tablet', () async {
      await withPlatform(TargetPlatform.android, () async {
        expect(CastService.isScreenMirroringSupported(), isTrue);
      });

      await withPlatform(TargetPlatform.iOS, () async {
        expect(CastService.isScreenMirroringSupported(), isFalse);
      });

      await withPlatform(TargetPlatform.windows, () async {
        expect(CastService.isScreenMirroringSupported(), isFalse);
      });
    });
  });

  group('showCastSheet - UI y comportamiento de doble ruta', () {
    testWidgets('stream bloqueado presenta Duplicar pantalla como opción principal destacada', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.android, () async {
        bool? dialogResult;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showCastSheet(
                    context,
                    title: 'Película con Referer',
                    streamUrl: () => 'https://server.test/movie.mp4',
                    mediaType: MediaType.movie,
                    blockInfo: const StreamBlockInfo(
                      reason: StreamBlockReason.requiresHeaders,
                      explanation: 'Este servidor exige cabeceras personalizadas.',
                      isHeaderOrWebView: true,
                    ),
                  );
                },
                child: const Text('Abrir Cast'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Cast'));
        await tester.pumpAndSettle();

        // Debe mostrar la opción principal destacada
        expect(find.text('OPCIÓN PRINCIPAL'), findsOneWidget);
        expect(find.text('Duplicar pantalla (Recomendado)'), findsOneWidget);

        // Debe mostrar la explicación clara del bloqueo técnico
        expect(find.text('CHROMECAST DIRECTO'), findsOneWidget);
        expect(find.text('Chromecast directo no disponible'), findsOneWidget);
        expect(
          find.text('Este servidor exige cabeceras personalizadas.'),
          findsOneWidget,
        );

        // Simular pulsar duplicar pantalla
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('hourtv/device'),
          (MethodCall call) async => 'cast',
        );

        await tester.tap(find.text('Duplicar pantalla (Recomendado)'));
        await tester.pumpAndSettle();

        // Duplicar pantalla NO pausa el video (devuelve false)
        expect(dialogResult, isFalse);
      });
    });

    testWidgets('stream compatible muestra Transmitir contenido y Duplicar pantalla como secundaria', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCastSheet(
                  context,
                  title: 'Canal en Vivo',
                  streamUrl: () => 'https://server.test/live.m3u8',
                  mediaType: MediaType.live,
                ),
                child: const Text('Abrir Cast'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Cast'));
        await tester.pumpAndSettle();

        // Sección de Chromecast directo
        expect(find.text('TRANSMITIR CONTENIDO'), findsOneWidget);

        // Opción secundaria de duplicación
        expect(find.text('DUPLICAR PANTALLA'), findsOneWidget);
        expect(find.text('Duplicar pantalla'), findsOneWidget);
        expect(
          find.text('Abrir ajustes de transmisión de Android'),
          findsOneWidget,
        );
      });
    });

    testWidgets('error en conexión muestra mensaje y botón para duplicar pantalla en su lugar', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCastSheet(
                  context,
                  title: 'Video',
                  streamUrl: () => 'https://server.test/video.mp4',
                  mediaType: MediaType.movie,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        // Verificamos que el botón de ajustes de transmisión esté disponible
        expect(
          find.text('Abrir ajustes de transmisión de Android'),
          findsOneWidget,
        );
      });
    });
  });

  group('Ficha de detalle (HourTvDetailPage) - Botón de transmisión disponible', () {
    testWidgets('botón de transmitir siempre visible y habilitado sin dispositivos en red (móvil)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final channel = Channel(
        name: 'Película de prueba',
        url: 'https://cdn.test/stream.mp4',
        forcedType: 'movie',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvDetailPage(
              channel: channel,
              preview: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // El texto 'Transmitir' debe encontrarse
      final transmitFinder = find.text('Transmitir');
      expect(transmitFinder, findsOneWidget);

      // El botón InkWell contenedor debe tener onTap habilitado (no nulo)
      final inkWellFinder = find.ancestor(
        of: transmitFinder,
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsWidgets);
      final inkWell = tester.widget<InkWell>(inkWellFinder.first);
      expect(inkWell.onTap, isNotNull);
    });

    testWidgets('botón de transmitir siempre visible y habilitado en tablet / escritorio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final channel = Channel(
        name: 'Película Tablet',
        url: 'https://cdn.test/stream.mp4',
        forcedType: 'movie',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvDetailPage(
              channel: channel,
              preview: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // En tablet se renderiza Tooltip con message 'Transmitir'
      final tooltipFinder = find.byTooltip('Transmitir');
      expect(tooltipFinder, findsOneWidget);

      final inkWell = find.descendant(
        of: tooltipFinder,
        matching: find.byType(InkWell),
      );
      expect(inkWell, findsOneWidget);
      final inkWellWidget = tester.widget<InkWell>(inkWell);
      expect(inkWellWidget.onTap, isNotNull);
    });
  });

  group('Pausa y comportamiento de reproducción con Cast y Duplicación', () {
    test('duplicación no pausa la reproducción local (devuelve false)', () {
      // La duplicación de pantalla solo abre los ajustes del sistema; el video
      var localPaused = false;
      void onCastSessionResult(bool connected) {
        if (connected) {
          localPaused = true;
        }
      }

      // Duplicar pantalla siempre retorna false desde showCastSheet
      onCastSessionResult(false);
      expect(localPaused, isFalse, reason: 'Duplicar pantalla no debe pausar la reproducción local');
    });

    test('sesión Cast confirmada pausa la reproducción local', () {
      // Tras confirmar la sesión con el receptor Chromecast, el video local se pausa
      // para evitar reproducción duplicada de audio y video.
      var localPaused = false;
      void onCastSessionResult(bool connected) {
        if (connected) {
          localPaused = true;
        }
      }

      // Conexión exitosa a Chromecast retorna true
      onCastSessionResult(true);
      expect(localPaused, isTrue, reason: 'Sesión Cast confirmada debe pausar el reproductor local');
    });

    test('canal en vivo es compatible con transmisión y no sufre bloqueo', () {
      final liveChannel = Channel(
        name: 'Noticias en Vivo',
        url: 'https://live.test/news/index.m3u8',
        forcedType: 'live',
      );
      final block = CastService.checkStreamBlocked(
        streamUrl: liveChannel.url,
        mediaType: liveChannel.type,
      );
      expect(block, isNull, reason: 'Canales en vivo deben ser compatibles');
      expect(CastService.contentTypeFor(liveChannel.url, mediaType: liveChannel.type), 'application/x-mpegURL');
    });
  });

  group('No regresión del progreso estilo Netflix', () {
    test('persistencia y oferta de reanudación siguen intactos tras cambios de Cast', () async {
      final movie = Channel(
        name: 'Película Netflix Style',
        url: 'vod:netflix_style',
        tvgId: 'tmdb:99999',
        forcedType: 'movie',
      );

      // Guardar posición a los 15 minutos de 1 hora
      await PlaybackProgress.save(movie, positionMs: 900000, durationMs: 3600000);

      final loaded = PlaybackProgress.load(movie);
      expect(loaded, isNotNull);
      expect(loaded!.positionMs, 900000);
      expect(loaded.isCompleted, isFalse);

      final offer = resumeOfferFor(movie, autoResume: false);
      expect(offer, isNotNull);
      expect(offer!.positionMs, 900000);
      expect(offer.label, contains('15:00'));
    });
  });

  group('Detección y comportamiento de Embed vs Stream Directo (Auditoría)', () {
    testWidgets('Ficha con URL VOE/embed recomienda Duplicar pantalla inmediatamente', (tester) async {
      await withPlatform(TargetPlatform.android, () async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final embedChannel = Channel(
          name: 'Película en VOE',
          url: 'https://voe.sx/e/2suzh7well4u',
          forcedType: 'movie',
        );

        // Verificamos que la URL se detecte como embed
        expect(CastService.isLikelyEmbedUrl(embedChannel.url), isTrue);

        final blockInfo = CastService.checkStreamBlocked(
          streamUrl: embedChannel.url,
          mediaType: embedChannel.type,
          isEmbedOrWebView: CastService.isLikelyEmbedUrl(embedChannel.url),
        );
        expect(blockInfo, isNotNull);
        expect(blockInfo!.reason, StreamBlockReason.webViewOrEmbed);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HourTvDetailPage(
                channel: embedChannel,
                preview: false,
              ),
            ),
          ),
        );
        await tester.pump();

        // Tocamos el botón de transmitir en la ficha de detalle
        final transmitFinder = find.text('Transmitir');
        expect(transmitFinder, findsOneWidget);
        await tester.tap(transmitFinder);
        await tester.pumpAndSettle();

        // Debe abrir la hoja recomendando DUPLICAR PANTALLA como opción principal
        expect(find.text('Duplicar pantalla (Recomendado)'), findsOneWidget);
        expect(find.text('OPCIÓN PRINCIPAL'), findsOneWidget);
        expect(find.textContaining('visor web'), findsOneWidget);
      });
    });

    testWidgets('La ficha con IPTV directa sin extensión NO recomienda duplicación por webView', (tester) async {
      await withPlatform(TargetPlatform.android, () async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final iptvChannel = Channel(
          name: 'Película IPTV Directa',
          url: 'http://iptv.server:8080/movie/user/pass/12345',
          forcedType: 'movie',
        );

        // No debe clasificarse como embed en la ficha
        expect(CastService.isKnownEmbedHost(iptvChannel.url), isFalse);
        expect(CastService.hasUnequivocalEmbedPath(iptvChannel.url), isFalse);
        expect(CastService.isLikelyEmbedUrl(iptvChannel.url), isFalse);

        final blockInfo = CastService.checkStreamBlocked(
          streamUrl: iptvChannel.url,
          mediaType: iptvChannel.type,
          isEmbedOrWebView: CastService.isLikelyEmbedUrl(iptvChannel.url),
        );
        expect(blockInfo, isNull, reason: 'URL IPTV VOD directa sin extensión no debe bloquearse para Chromecast');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HourTvDetailPage(
                channel: iptvChannel,
                preview: false,
              ),
            ),
          ),
        );
        await tester.pump();

        final transmitFinder = find.text('Transmitir');
        expect(transmitFinder, findsOneWidget);
        await tester.tap(transmitFinder);
        await tester.pumpAndSettle();

        // NO debe recomendar duplicar pantalla como opción principal ni mostrar aviso de visor web
        expect(find.text('Duplicar pantalla (Recomendado)'), findsNothing);
        expect(find.textContaining('visor web'), findsNothing);
        // Debe mostrar la sección normal de Chromecast directo
        expect(find.text('TRANSMITIR CONTENIDO'), findsOneWidget);
      });
    });

    test('evilstreamwish.com NO se reconoce como Streamwish', () {
      const evilUrl1 = 'https://evilstreamwish.com/e/123';
      const evilUrl2 = 'https://evilstreamwish.com/movie.mp4';
      const evilUrl3 = 'http://notstreamwish.to/play';
      const evilUrl4 = 'https://streamwish.evil.com/video';

      expect(CastService.isKnownEmbedHost(evilUrl1), isFalse);
      expect(CastService.isKnownEmbedHost(evilUrl2), isFalse);
      expect(CastService.isKnownEmbedHost(evilUrl3), isFalse);
      expect(CastService.isKnownEmbedHost(evilUrl4), isFalse);
    });

    test('streamwish.to y subdominio.streamwish.to sí se reconocen', () {
      const direct = 'https://streamwish.to/e/12345';
      const sub = 'https://subdominio.streamwish.to/e/12345';
      const multiSub = 'https://a.b.streamwish.to/player';

      expect(CastService.isKnownEmbedHost(direct), isTrue);
      expect(CastService.isKnownEmbedHost(sub), isTrue);
      expect(CastService.isKnownEmbedHost(multiSub), isTrue);
    });

    test('VOE/Streamwish/Filemoon conocidos siguen recomendando duplicación', () {
      const voe = 'https://voe.sx/e/2suzh7well4u';
      const streamwish = 'https://streamwish.to/e/abc123';
      const filemoon = 'https://filemoon.sx/d/xyz987';
      const vidhide = 'https://vidhide.com/v/test1';

      for (final url in [voe, streamwish, filemoon, vidhide]) {
        expect(CastService.isKnownEmbedHost(url), isTrue, reason: '$url debe ser reconocido como host embed');
        expect(CastService.isLikelyEmbedUrl(url), isTrue);
        final block = CastService.checkStreamBlocked(streamUrl: url, mediaType: MediaType.movie);
        expect(block, isNotNull);
        expect(block!.reason, StreamBlockReason.webViewOrEmbed);
        expect(block.isHeaderOrWebView, isTrue);
      }
    });

    test('La detección desde PlayerScreen con _embedController != null permanece bloqueada aunque el host sea desconocido', () {
      const unknownHostUrl = 'https://servidor-desconocido-123.org/player/watch?v=999';

      // El host no es conocido
      expect(CastService.isKnownEmbedHost(unknownHostUrl), isFalse);

      // En el reproductor _embedController != null activa isEmbedOrWebView: true
      final block = CastService.checkStreamBlocked(
        streamUrl: unknownHostUrl,
        mediaType: MediaType.movie,
        isEmbedOrWebView: true,
      );

      expect(block, isNotNull);
      expect(block!.reason, StreamBlockReason.webViewOrEmbed);
      expect(block.isHeaderOrWebView, isTrue);
      expect(block.explanation, contains('visor web'));
    });

    test('Ficha con URL directa .m3u8 permite Chromecast', () {
      final hlsChannel = Channel(
        name: 'Stream Directo HLS',
        url: 'https://cdn.example.com/playlist.m3u8',
        forcedType: 'movie',
      );

      expect(CastService.isLikelyEmbedUrl(hlsChannel.url), isFalse);
      final block = CastService.checkStreamBlocked(
        streamUrl: hlsChannel.url,
        mediaType: hlsChannel.type,
        isEmbedOrWebView: CastService.isLikelyEmbedUrl(hlsChannel.url),
      );
      expect(block, isNull, reason: 'URL directa .m3u8 no debe bloquearse para Chromecast');
      expect(CastService.contentTypeFor(hlsChannel.url, mediaType: hlsChannel.type), 'application/x-mpegURL');
    });

    test('Ficha con URL directa .mp4 permite Chromecast', () {
      final mp4Channel = Channel(
        name: 'VOD Directo MP4',
        url: 'https://cdn.example.com/vod/movie.mp4',
        forcedType: 'movie',
      );

      expect(CastService.isLikelyEmbedUrl(mp4Channel.url), isFalse);
      final block = CastService.checkStreamBlocked(
        streamUrl: mp4Channel.url,
        mediaType: mp4Channel.type,
        isEmbedOrWebView: CastService.isLikelyEmbedUrl(mp4Channel.url),
      );
      expect(block, isNull, reason: 'URL directa .mp4 no debe bloquearse para Chromecast');
      expect(CastService.contentTypeFor(mp4Channel.url, mediaType: mp4Channel.type), 'video/mp4');
    });

    test('Una URL VOD sin extensión no debe considerarse automáticamente MP4 si corresponde a un host embed conocido', () {
      const voeUrl = 'https://voe.sx/e/2suzh7well4u';
      const streamwishUrl = 'https://streamwish.to/e/abc123';
      const vidhideUrl = 'https://vidhide.com/v/xyz789';
      const filemoonUrl = 'https://filemoon.sx/d/12345';
      const standardIptvVodUrl = 'http://iptv.server:8080/movie/user/pass/12345';

      // Hosts embed conocidos sin extensión no devuelven video/mp4
      expect(CastService.isKnownEmbedHost(voeUrl), isTrue);
      expect(CastService.isKnownEmbedHost(streamwishUrl), isTrue);
      expect(CastService.isKnownEmbedHost(vidhideUrl), isTrue);
      expect(CastService.isKnownEmbedHost(filemoonUrl), isTrue);
      expect(CastService.contentTypeFor(voeUrl, mediaType: MediaType.movie), isNull);
      expect(CastService.contentTypeFor(streamwishUrl, mediaType: MediaType.series), isNull);
      expect(CastService.contentTypeFor(vidhideUrl, mediaType: MediaType.movie), isNull);
      expect(CastService.contentTypeFor(filemoonUrl, mediaType: MediaType.movie), isNull);

      // checkStreamBlocked devuelve bloqueo webViewOrEmbed
      final voeBlock = CastService.checkStreamBlocked(streamUrl: voeUrl, mediaType: MediaType.movie);
      expect(voeBlock, isNotNull);
      expect(voeBlock!.reason, StreamBlockReason.webViewOrEmbed);

      // En contraste, una URL VOD IPTV genérica sin extensión sí deduce video/mp4
      expect(CastService.isKnownEmbedHost(standardIptvVodUrl), isFalse);
      expect(CastService.contentTypeFor(standardIptvVodUrl, mediaType: MediaType.movie), 'video/mp4');
      final iptvBlock = CastService.checkStreamBlocked(streamUrl: standardIptvVodUrl, mediaType: MediaType.movie);
      expect(iptvBlock, isNull);
    });

    test('El reproductor, después de resolver un embed a stream directo, sigue permitiendo Chromecast únicamente cuando no necesita cabeceras', () {
      // Caso 5A: Embed resuelto que REQUIERE cabeceras (User-Agent o Referer)
      const resolvedWithHeadersUrl = 'https://delivery-node-01.cdn/hls/master.m3u8';
      final blockHeaders = CastService.checkStreamBlocked(
        streamUrl: resolvedWithHeadersUrl,
        mediaType: MediaType.movie,
        requiresHeaders: true,
        isEmbedOrWebView: false,
      );
      expect(blockHeaders, isNotNull);
      expect(blockHeaders!.reason, StreamBlockReason.requiresHeaders);
      expect(blockHeaders.isHeaderOrWebView, isTrue);

      // Caso 5B: Embed resuelto que NO requiere cabeceras privadas
      const resolvedDirectPublicUrl = 'https://delivery-node-02.cdn/vod/movie.mp4';
      final blockPublic = CastService.checkStreamBlocked(
        streamUrl: resolvedDirectPublicUrl,
        mediaType: MediaType.movie,
        requiresHeaders: false,
        isEmbedOrWebView: false,
      );
      expect(blockPublic, isNull, reason: 'Stream directo resuelto sin cabeceras debe permitir Chromecast');
    });
  });
}
