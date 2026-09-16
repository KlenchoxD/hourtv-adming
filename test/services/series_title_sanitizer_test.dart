import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/catalog/series_title_sanitizer.dart';

void main() {
  group('SeriesTitleSanitizer (Presentation Only)', () {
    test('Preserves valid season titles and years', () {
      expect(
        SeriesTitleSanitizer.sanitize('Breaking Bad - Temporada 1'),
        equals('Breaking Bad - Temporada 1'),
      );
      expect(
        SeriesTitleSanitizer.sanitize('Stranger Things: Temporada 4 (2022)'),
        equals('Stranger Things: Temporada 4 (2022)'),
      );
      expect(
        SeriesTitleSanitizer.sanitize('House of the Dragon Season 2'),
        equals('House of the Dragon Season 2'),
      );
      expect(
        SeriesTitleSanitizer.sanitize('Attack on Titan T4'),
        equals('Attack on Titan T4'),
      );
    });

    test('Strips obvious website suffixes, scraper brands and technical junk', () {
      expect(
        SeriesTitleSanitizer.sanitize('Loki | Blog de Pelis'),
        equals('Loki'),
      );
      expect(
        SeriesTitleSanitizer.sanitize('The Boys - Temporada 3 [1080p Dual] | CineCalidad.com'),
        equals('The Boys - Temporada 3'),
      );
      expect(
        SeriesTitleSanitizer.sanitize('Better Call Saul (2015) | Cuevana 3'),
        equals('Better Call Saul (2015)'),
      );
      expect(
        SeriesTitleSanitizer.sanitize('Euphoria - Temporada 2 [HD-RIP 720p] - PelisPlus.net'),
        equals('Euphoria - Temporada 2'),
      );
    });

    test('Leaves already clean titles untouched', () {
      expect(
        SeriesTitleSanitizer.sanitize('The Mandalorian'),
        equals('The Mandalorian'),
      );
      expect(
        SeriesTitleSanitizer.sanitize('Spider-Man: Homecoming'),
        equals('Spider-Man: Homecoming'),
      );
    });
  });
}
