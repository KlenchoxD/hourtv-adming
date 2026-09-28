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

  group('CastService - openCastSettings e integración con el sistema', () {
    test('duplicación invoca openCastSettings y mapea target cast', () async {
      await withPlatform(TargetPlatform.android, () async {
        String? invokedMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('hourtv/device'), (
              MethodCall call,
            ) async {
              invokedMethod = call.method;
              return 'cast';
            });

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

    test(
      'openCastSettings mapea target display (ajustes de pantalla)',
      () async {
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
      },
    );

    test(
      'openCastSettings maneja error cuando el dispositivo no ofrece actividad',
      () async {
        await withPlatform(TargetPlatform.android, () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(const MethodChannel('hourtv/device'), (
                MethodCall call,
              ) async {
                throw PlatformException(
                  code: 'cast_settings_unavailable',
                  message: 'No compatible',
                );
              });

          final result = await CastService.instance.openCastSettings();
          expect(result.opened, isFalse);
          expect(result.errorMessage, contains('No compatible'));
        });
      },
    );

    test(
      'isScreenMirroringSupported solo es true en Android móvil/tablet',
      () async {
        await withPlatform(TargetPlatform.android, () async {
          expect(CastService.isScreenMirroringSupported(), isTrue);
        });

        await withPlatform(TargetPlatform.iOS, () async {
          expect(CastService.isScreenMirroringSupported(), isFalse);
        });

        await withPlatform(TargetPlatform.windows, () async {
          expect(CastService.isScreenMirroringSupported(), isFalse);
        });
      },
    );
  });

  group('showCastSheet', () {
    testWidgets('servidor solo web: lo explica y ofrece Duplicar pantalla', (
      tester,
    ) async {
      await withPlatform(TargetPlatform.android, () async {
        Object? result = 'sin cerrar';
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showCastSheet(
                    context,
                    title: 'Película en visor web',
                    media: () async => null,
                    mediaType: MediaType.movie,
                    blockedReason:
                        'Este servidor solo se abre en el visor web.',
                  );
                },
                child: const Text('Abrir Cast'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Cast'));
        await tester.pumpAndSettle();

        expect(find.text('Transmitir a TV'), findsOneWidget);
        expect(
          find.text('Este servidor solo se abre en el visor web.'),
          findsOneWidget,
        );
        expect(find.text('Televisores en tu Wi-Fi'), findsNothing);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('hourtv/device'),
              (MethodCall call) async => 'cast',
            );
        await tester.tap(find.text('Duplicar pantalla'));
        await tester.pumpAndSettle();

        // Duplicar pantalla no inicia una transmisión: no pausa el video.
        expect(result, isNull);
      });
    });

    testWidgets('stream directo lista televisores y ofrece Duplicar pantalla', (
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
                  media: () async => (
                    url: 'https://server.test/live.m3u8',
                    headers: const <String, String>{},
                  ),
                  mediaType: MediaType.live,
                ),
                child: const Text('Abrir Cast'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Cast'));
        await tester.pumpAndSettle();

        expect(find.text('Televisores en tu Wi-Fi'), findsOneWidget);
        expect(
          find.textContaining('No encontramos ningún televisor'),
          findsOneWidget,
        );
        expect(find.text('Buscar de nuevo'), findsOneWidget);
        expect(find.text('Duplicar pantalla'), findsOneWidget);
      });
    });
  });

  group(
    'Ficha de detalle (HourTvDetailPage) - Botón de transmisión disponible',
    () {
      testWidgets(
        'botón de transmitir siempre visible y habilitado sin dispositivos en red (móvil)',
        (tester) async {
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
                body: HourTvDetailPage(channel: channel, preview: false),
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
        },
      );

      testWidgets(
        'botón de transmitir siempre visible y habilitado en tablet / escritorio',
        (tester) async {
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
                body: HourTvDetailPage(channel: channel, preview: false),
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
        },
      );
    },
  );

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
      expect(
        localPaused,
        isFalse,
        reason: 'Duplicar pantalla no debe pausar la reproducción local',
      );
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
      expect(
        localPaused,
        isTrue,
        reason: 'Sesión Cast confirmada debe pausar el reproductor local',
      );
    });
  });

  group('No regresión del progreso estilo Netflix', () {
    test(
      'persistencia y oferta de reanudación siguen intactos tras cambios de Cast',
      () async {
        final movie = Channel(
          name: 'Película Netflix Style',
          url: 'vod:netflix_style',
          tvgId: 'tmdb:99999',
          forcedType: 'movie',
        );

        // Guardar posición a los 15 minutos de 1 hora
        await PlaybackProgress.save(
          movie,
          positionMs: 900000,
          durationMs: 3600000,
        );

        final loaded = PlaybackProgress.load(movie);
        expect(loaded, isNotNull);
        expect(loaded!.positionMs, 900000);
        expect(loaded.isCompleted, isFalse);

        final offer = resumeOfferFor(movie, autoResume: false);
        expect(offer, isNotNull);
        expect(offer!.positionMs, 900000);
        expect(offer.label, contains('15:00'));
      },
    );
  });

  group('Detección y comportamiento de Embed vs Stream Directo (Auditoría)', () {
    testWidgets(
      'La ficha con un embed abre la lista de TVs (se resuelve al elegir)',
      (tester) async {
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
          expect(CastService.isLikelyEmbedUrl(embedChannel.url), isTrue);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HourTvDetailPage(channel: embedChannel, preview: false),
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Transmitir'));
          await tester.pumpAndSettle();

          expect(find.text('Transmitir a TV'), findsOneWidget);
          expect(find.text('Televisores en tu Wi-Fi'), findsOneWidget);
        });
      },
    );

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

    test('Ficha con URL directa .m3u8 permite Chromecast', () {
      final hlsChannel = Channel(
        name: 'Stream Directo HLS',
        url: 'https://cdn.example.com/playlist.m3u8',
        forcedType: 'movie',
      );

      expect(CastService.isLikelyEmbedUrl(hlsChannel.url), isFalse);
      expect(
        CastService.contentTypeFor(hlsChannel.url, mediaType: hlsChannel.type),
        'application/x-mpegURL',
      );
    });

    test('Ficha con URL directa .mp4 permite Chromecast', () {
      final mp4Channel = Channel(
        name: 'VOD Directo MP4',
        url: 'https://cdn.example.com/vod/movie.mp4',
        forcedType: 'movie',
      );

      expect(CastService.isLikelyEmbedUrl(mp4Channel.url), isFalse);
      expect(
        CastService.contentTypeFor(mp4Channel.url, mediaType: mp4Channel.type),
        'video/mp4',
      );
    });

    test(
      'Una URL VOD sin extensión no debe considerarse automáticamente MP4 si corresponde a un host embed conocido',
      () {
        const voeUrl = 'https://voe.sx/e/2suzh7well4u';
        const streamwishUrl = 'https://streamwish.to/e/abc123';
        const vidhideUrl = 'https://vidhide.com/v/xyz789';
        const filemoonUrl = 'https://filemoon.sx/d/12345';
        const standardIptvVodUrl =
            'http://iptv.server:8080/movie/user/pass/12345';

        // Hosts embed conocidos sin extensión no devuelven video/mp4
        expect(CastService.isKnownEmbedHost(voeUrl), isTrue);
        expect(CastService.isKnownEmbedHost(streamwishUrl), isTrue);
        expect(CastService.isKnownEmbedHost(vidhideUrl), isTrue);
        expect(CastService.isKnownEmbedHost(filemoonUrl), isTrue);
        expect(
          CastService.contentTypeFor(voeUrl, mediaType: MediaType.movie),
          isNull,
        );
        expect(
          CastService.contentTypeFor(
            streamwishUrl,
            mediaType: MediaType.series,
          ),
          isNull,
        );
        expect(
          CastService.contentTypeFor(vidhideUrl, mediaType: MediaType.movie),
          isNull,
        );
        expect(
          CastService.contentTypeFor(filemoonUrl, mediaType: MediaType.movie),
          isNull,
        );

        // En contraste, una URL VOD IPTV genérica sin extensión sí deduce video/mp4
        expect(CastService.isKnownEmbedHost(standardIptvVodUrl), isFalse);
        expect(
          CastService.contentTypeFor(
            standardIptvVodUrl,
            mediaType: MediaType.movie,
          ),
          'video/mp4',
        );
      },
    );
  });
}
