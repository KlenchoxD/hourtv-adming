import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/ad_service.dart';

void main() {
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
  });
}
