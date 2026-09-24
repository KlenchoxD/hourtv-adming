import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/ad_service.dart';

void main() {
  test('usa el SmartLink activo de Adsterra', () {
    final uri = Uri.parse(AdService.smartlink);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.profitableratecpmnetwork.com');
  });

  group('AdService.shouldShowPreroll', () {
    test('no muestra anuncios en canales en vivo', () {
      final channel = Channel(
        name: 'Canal en vivo',
        url: 'https://example.com/live.m3u8',
      );

      expect(channel.type, MediaType.live);
      expect(AdService.shouldShowPreroll(channel), isFalse);
    });

    test('muestra preroll en películas y episodios', () {
      final movie = Channel(
        name: 'Película',
        url: 'https://example.com/movie.mp4',
        forcedType: 'movie',
      );
      final episode = Channel(
        name: 'Episodio',
        url: 'https://example.com/episode.mp4',
        forcedType: 'series',
      );

      expect(AdService.shouldShowPreroll(movie), isTrue);
      expect(AdService.shouldShowPreroll(episode), isTrue);
    });
  });

  group('AdService preroll load failures', () {
    test('a main-frame error releases the playback gate', () {
      expect(
        AdService.shouldReleasePrerollAfterLoadError(isForMainFrame: true),
        isTrue,
      );
    });

    test('a subresource error does not prematurely release the ad page', () {
      expect(
        AdService.shouldReleasePrerollAfterLoadError(isForMainFrame: false),
        isFalse,
      );
    });

    test('a timeout releases a preroll whose countdown never started', () {
      expect(
        AdService.shouldReleasePrerollAtTimeout(
          mounted: true,
          countdownStarted: false,
        ),
        isTrue,
      );
      expect(
        AdService.shouldReleasePrerollAtTimeout(
          mounted: true,
          countdownStarted: true,
        ),
        isFalse,
      );
      expect(
        AdService.shouldReleasePrerollAtTimeout(
          mounted: false,
          countdownStarted: false,
        ),
        isFalse,
      );
    });
  });

  group('PrerollSession', () {
    test('muestra un solo anuncio durante una sesión de reproducción', () {
      final session = PrerollSession();
      final movie = Channel(
        name: 'Película',
        url: 'https://example.com/movie.mp4',
        forcedType: 'movie',
      );
      final episode = Channel(
        name: 'Episodio siguiente',
        url: 'https://example.com/episode.mp4',
        forcedType: 'series',
      );

      expect(session.takeIfNeeded(movie), isTrue);
      expect(session.takeIfNeeded(movie), isFalse);
      expect(session.takeIfNeeded(episode), isFalse);
    });

    test('un canal en vivo no consume el anuncio de la sesión', () {
      final session = PrerollSession();
      final live = Channel(name: 'Canal', url: 'https://example.com/live.m3u8');
      final movie = Channel(
        name: 'Película',
        url: 'https://example.com/movie.mp4',
        forcedType: 'movie',
      );

      expect(session.takeIfNeeded(live), isFalse);
      expect(session.takeIfNeeded(movie), isTrue);
    });
  });

  group('AdService.allowsContainedNavigation', () {
    test('permite la cadena inicial de redirecciones https', () {
      expect(
        AdService.allowsContainedNavigation(
          AdService.smartlink,
          lockedHost: null,
        ),
        isTrue,
      );
    });

    test('bloquea protocolos y dominios externos tras cargar el anuncio', () {
      expect(
        AdService.allowsContainedNavigation(
          'intent://external-app',
          lockedHost: 'landing.example',
        ),
        isFalse,
      );
      expect(
        AdService.allowsContainedNavigation(
          'https://outside.example/path',
          lockedHost: 'landing.example',
        ),
        isFalse,
      );
      expect(
        AdService.allowsContainedNavigation(
          'https://landing.example/next',
          lockedHost: 'landing.example',
        ),
        isTrue,
      );
    });

    test(
      'permite redirección desde el intermediario de Smartlink hacia el anunciante',
      () {
        // Si el proveedor intermediario de Smartlink está como lockedHost provisional,
        // no debe impedir la navegación a la oferta legítima del anunciante.
        expect(
          AdService.allowsContainedNavigation(
            'https://anunciante.com/landing',
            lockedHost: 'www.profitableratecpmnetwork.com',
          ),
          isTrue,
        );
        expect(
          AdService.isSmartlinkProvider('www.profitableratecpmnetwork.com'),
          isTrue,
        );
        expect(
          AdService.isSmartlinkProvider(
            'subdomain.profitableratecpmnetwork.com',
          ),
          isTrue,
        );
        expect(AdService.isSmartlinkProvider('anunciante.com'), isFalse);
      },
    );

    test('sanitiza hosts sin exponer parámetros de URL ni claves', () {
      final sanitized = AdService.sanitizeHost(AdService.smartlink);
      expect(sanitized, 'www.profitableratecpmnetwork.com');
      expect(sanitized.contains('key'), isFalse);
      expect(sanitized.contains('02db82eac7ad89e5799436cbc25c9946'), isFalse);
    });
  });
}
