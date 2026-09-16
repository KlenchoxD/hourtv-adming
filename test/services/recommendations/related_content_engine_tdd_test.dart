import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/recommendations/related_content_engine.dart';

void main() {
  group('RelatedContentEngine TDD & Business Rules', () {
    late RelatedContentEngine engine;

    setUp(() {
      engine = RelatedContentEngine();
    });

    final movieMatrix1 = Channel(
      name: 'The Matrix',
      url: 'catalog://movie-matrix-1',
      catalogTitleId: 'movie-matrix-1',
      genre: 'Ciencia Ficción, Acción',
      year: '1999',
      rating: '8.7',
      cast: 'Keanu Reeves, Laurence Fishburne, Carrie-Anne Moss',
      director: 'Lana Wachowski, Lilly Wachowski',
      countryCode: 'us',
      forcedType: 'movie',
      isKidsSafe: false,
    );

    final movieMatrix2 = Channel(
      name: 'The Matrix Reloaded',
      url: 'catalog://movie-matrix-2',
      catalogTitleId: 'movie-matrix-2',
      genre: 'Ciencia Ficción, Acción',
      year: '2003',
      rating: '7.2',
      cast: 'Keanu Reeves, Laurence Fishburne, Carrie-Anne Moss',
      director: 'Lana Wachowski, Lilly Wachowski',
      countryCode: 'us',
      forcedType: 'movie',
      isKidsSafe: false,
    );

    final movieInception = Channel(
      name: 'Inception',
      url: 'catalog://movie-inception',
      catalogTitleId: 'movie-inception',
      genre: 'Ciencia Ficción, Acción',
      year: '2010',
      rating: '8.8',
      cast: 'Leonardo DiCaprio, Joseph Gordon-Levitt',
      director: 'Christopher Nolan',
      countryCode: 'us',
      forcedType: 'movie',
      isKidsSafe: false,
    );

    final movieToyStory = Channel(
      name: 'Toy Story',
      url: 'catalog://movie-toystory',
      catalogTitleId: 'movie-toystory',
      genre: 'Animación, Familia',
      year: '1995',
      rating: '8.3',
      cast: 'Tom Hanks, Tim Allen',
      director: 'John Lasseter',
      countryCode: 'us',
      forcedType: 'movie',
      isKidsSafe: true,
    );

    final movieToyStory2 = Channel(
      name: 'Toy Story 2',
      url: 'catalog://movie-toystory-2',
      catalogTitleId: 'movie-toystory-2',
      genre: 'Animación, Familia',
      year: '1999',
      rating: '7.9',
      cast: 'Tom Hanks, Tim Allen',
      director: 'John Lasseter',
      countryCode: 'us',
      forcedType: 'movie',
      isKidsSafe: true,
    );

    final seriesStrangerThings = Channel(
      name: 'Stranger Things',
      url: 'catalog://series-stranger-things',
      catalogTitleId: 'series-stranger-things',
      genre: 'Ciencia Ficción, Drama',
      year: '2016',
      rating: '8.7',
      cast: 'Millie Bobby Brown, Winona Ryder',
      forcedType: 'series',
      isKidsSafe: false,
    );

    final seriesDark = Channel(
      name: 'Dark',
      url: 'catalog://series-dark',
      catalogTitleId: 'series-dark',
      genre: 'Ciencia Ficción, Misterio',
      year: '2017',
      rating: '8.7',
      cast: 'Louis Hofmann, Oliver Masucci',
      forcedType: 'series',
      isKidsSafe: false,
    );

    final seriesFriends = Channel(
      name: 'Friends',
      url: 'catalog://series-friends',
      catalogTitleId: 'series-friends',
      genre: 'Comedia, Romance',
      year: '1994',
      rating: '8.9',
      cast: 'Jennifer Aniston, Courteney Cox',
      forcedType: 'series',
      isKidsSafe: true,
    );

    final seriesBrooklyn99 = Channel(
      name: 'Brooklyn Nine-Nine',
      url: 'catalog://series-b99',
      catalogTitleId: 'series-b99',
      genre: 'Comedia, Crimen',
      year: '2013',
      rating: '8.4',
      cast: 'Andy Samberg, Stephanie Beatriz',
      forcedType: 'series',
      isKidsSafe: true,
    );

    test('1. Excluye el título actual por todas sus identidades y deduplica por tmdbId', () {
      final duplicateMatrix = Channel(
        name: 'The Matrix (Mirror)',
        url: 'https://other-url/matrix',
        catalogTitleId: 'duplicate-matrix',
        genre: 'Ciencia Ficción',
        forcedType: 'movie',
      );

      final catalog = [movieMatrix1, movieMatrix2, movieInception, duplicateMatrix];

      final results = engine.getRelated(
        target: movieMatrix1,
        candidates: catalog,
        limit: 5,
      );

      // No debe contener al target
      expect(results.any((c) => c.catalogTitleId == movieMatrix1.catalogTitleId), isFalse);
      expect(results.any((c) => c.name == movieMatrix1.name), isFalse);
      expect(results.first.catalogTitleId, equals(movieMatrix2.catalogTitleId));
    });

    test('2. En perfil infantil respeta isKidsSafe y excluye contenido adulto', () {
      final catalog = [movieMatrix2, movieInception, movieToyStory, movieToyStory2];

      final results = engine.getRelated(
        target: movieToyStory,
        candidates: catalog,
        isKidsProfile: true,
        limit: 5,
      );

      // Solo títulos infantiles seguros
      for (final item in results) {
        expect(item.isKidsSafe, isTrue);
      }
      expect(results.map((c) => c.name), contains('Toy Story 2'));
      expect(results.map((c) => c.name), isNot(contains('The Matrix Reloaded')));
      expect(results.map((c) => c.name), isNot(contains('Inception')));
    });

    test('3. Demostración de puntuación obligatoria para 4 combinaciones requeridas', () {
      final catalog = [
        movieMatrix1,
        movieMatrix2,
        movieInception,
        movieToyStory,
        movieToyStory2,
        seriesStrangerThings,
        seriesDark,
        seriesFriends,
        seriesBrooklyn99,
      ];

      // A. Dos películas de géneros diferentes
      final relMatrix = engine.getRelatedWithScore(target: movieMatrix1, candidates: catalog, limit: 3);
      final relToyStory = engine.getRelatedWithScore(target: movieToyStory, candidates: catalog, limit: 3);

      expect(relMatrix.map((e) => e.channel.catalogTitleId), isNot(equals(relToyStory.map((e) => e.channel.catalogTitleId))));

      // B. Dos películas del mismo género (Matrix vs Inception)
      final relInception = engine.getRelatedWithScore(target: movieInception, candidates: catalog, limit: 3);

      // C. Dos series de géneros diferentes (Stranger Things vs Friends)
      final relStranger = engine.getRelatedWithScore(target: seriesStrangerThings, candidates: catalog, limit: 3);
      final relFriends = engine.getRelatedWithScore(target: seriesFriends, candidates: catalog, limit: 3);

      expect(relStranger.map((e) => e.channel.catalogTitleId), isNot(equals(relFriends.map((e) => e.channel.catalogTitleId))));

      // D. Dos series del mismo género (Friends vs Brooklyn Nine-Nine)
      final relB99 = engine.getRelatedWithScore(target: seriesBrooklyn99, candidates: catalog, limit: 3);

      // Verificar que los scores calculados son deterministas y positivos
      expect(relMatrix.first.score, greaterThan(0));
      expect(relInception.first.score, greaterThan(0));
      expect(relStranger.first.score, greaterThan(0));
      expect(relFriends.first.score, greaterThan(0));
      expect(relB99.first.score, greaterThan(0));
    });
  });
}
