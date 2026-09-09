import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_genre_service.dart';
import 'package:streamtv/models/channel.dart';

void main() {
  group('HourTvGenreService', () {
    test('extracts genres from genre, categories and useful group', () {
      final item = Channel(
        name: 'Item 1',
        url: 'movie://1',
        genre: 'Acción, Drama',
        categories: const ['Crimen / Suspenso'],
        group: 'Películas | Misterio',
      );

      final genres = HourTvGenreService.extractItemGenres(item);

      expect(genres, contains('Acción'));
      expect(genres, contains('Drama'));
      expect(genres, contains('Crimen'));
      expect(genres, contains('Suspenso'));
      expect(genres, contains('Misterio'));
      expect(genres, isNot(contains('Películas')));
    });

    test('splits multiple delimiters including comma, slash, pipe, semicolon and bullet', () {
      final item = Channel(
        name: 'Item 2',
        url: 'movie://2',
        genre: 'Aventura; Fantasía • Romance | Comedia / Terror',
      );

      final genres = HourTvGenreService.extractItemGenres(item);

      expect(genres, contains('Aventura'));
      expect(genres, contains('Fantasía'));
      expect(genres, contains('Romance'));
      expect(genres, contains('Comedia'));
      expect(genres, contains('Terror'));
    });

    test('filters out technical junk, codecs, resolutions and content types', () {
      final item = Channel(
        name: 'Junk Item',
        url: 'movie://junk',
        genre: '4K, FHD, 1080p, HEVC, H264, Latino, Dual, Subtitulado',
        categories: const ['Películas', 'Series', 'VOD', 'Estrenos', 'Top'],
        group: 'ES | Canales VIP 2024',
      );

      final genres = HourTvGenreService.extractItemGenres(item);

      expect(genres, isEmpty);
    });

    test('filters out country names and ISO country codes', () {
      final item = Channel(
        name: 'Country Item',
        url: 'movie://country',
        genre: 'Colombia, España, Estados Unidos, MX, AR',
      );

      final genres = HourTvGenreService.extractItemGenres(item);

      expect(genres, isEmpty);
    });

    test('deduplicates case and accents preserving readable representation', () {
      final items = [
        Channel(name: 'A', url: '1', genre: 'accion'),
        Channel(name: 'B', url: '2', genre: 'Acción'),
        Channel(name: 'C', url: '3', genre: 'ciencia ficcion'),
        Channel(name: 'D', url: '4', genre: 'Ciencia Ficción'),
      ];

      final available = HourTvGenreService.getAvailableGenres(items);

      expect(available.first, HourTvGenreService.defaultGenre);
      expect(available.where((g) => HourTvGenreService.normalize(g) == 'accion').length, 1);
      expect(available, contains('Acción'));
      expect(available, contains('Ciencia Ficción'));
    });

    test('sorts alphabetically after Todos los géneros', () {
      final items = [
        Channel(name: '1', url: '1', genre: 'Terror'),
        Channel(name: '2', url: '2', genre: 'Animación'),
        Channel(name: '3', url: '3', genre: 'Comedia'),
      ];

      final available = HourTvGenreService.getAvailableGenres(items);

      expect(available, [
        HourTvGenreService.defaultGenre,
        'Animación',
        'Comedia',
        'Terror',
      ]);
    });

    test('channelMatchesGenre accurately matches single and multiple genres', () {
      final item = Channel(
        name: 'Movie',
        url: 'movie://m',
        genre: 'Acción, Drama',
      );

      expect(HourTvGenreService.channelMatchesGenre(item, HourTvGenreService.defaultGenre), isTrue);
      expect(HourTvGenreService.channelMatchesGenre(item, 'Acción'), isTrue);
      expect(HourTvGenreService.channelMatchesGenre(item, 'accion'), isTrue);
      expect(HourTvGenreService.channelMatchesGenre(item, 'Drama'), isTrue);
      expect(HourTvGenreService.channelMatchesGenre(item, 'Comedia'), isFalse);
    });

    test('handles missing or null genres gracefully without errors', () {
      final item = Channel(name: 'Empty', url: 'movie://empty');

      expect(HourTvGenreService.extractItemGenres(item), isEmpty);
      expect(HourTvGenreService.channelMatchesGenre(item, HourTvGenreService.defaultGenre), isTrue);
      expect(HourTvGenreService.channelMatchesGenre(item, 'Drama'), isFalse);
    });

    test('strictly validates Channel.group against recognized genres, rejecting grouping phrases', () {
      final junkGroups = [
        'Series Anime',
        'Telenovelas RCN',
        'Películas Latino',
        'VOD Premium',
        'Canales VIP 2024',
      ];

      for (final groupTitle in junkGroups) {
        final item = Channel(
          name: 'Item with $groupTitle',
          url: 'movie://test',
          group: groupTitle,
        );
        final genres = HourTvGenreService.extractItemGenres(item);
        expect(
          genres,
          isEmpty,
          reason: 'Group "$groupTitle" must not produce any genre',
        );
      }

      final validGroup1 = Channel(
        name: 'Drama Movie',
        url: 'movie://drama',
        group: 'Drama',
      );
      expect(HourTvGenreService.extractItemGenres(validGroup1), equals({'Drama'}));

      final validGroup2 = Channel(
        name: 'Action Adventure Movie',
        url: 'movie://act-adv',
        group: 'Acción / Aventura',
      );
      expect(
        HourTvGenreService.extractItemGenres(validGroup2),
        containsAll({'Acción', 'Aventura'}),
      );
    });
  });
}
