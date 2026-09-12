import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/user_data_dao.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/recommendations/recommendation_engine.dart';

void main() {
  late CatalogDatabase db;
  late UserDataDao dao;
  late RecommendationEngine engine;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = db.userDataDao;
    engine = RecommendationEngine(userDataDao: dao);
  });

  tearDown(() async {
    await db.close();
  });

  group('RecommendationEngine Tests', () {
    final kidsSafeMovie = Channel(
      name: 'Toy Story Animada',
      url: 'catalog://movie-toy-story',
      catalogTitleId: 'movie-toy-story',
      genre: 'Animación',
      rating: '8.5',
      isKidsSafe: true,
      forcedType: 'movie',
    );

    final regularActionMovie = Channel(
      name: 'John Wick Acción',
      url: 'catalog://movie-john-wick',
      catalogTitleId: 'movie-john-wick',
      genre: 'Acción',
      rating: '8.0',
      isKidsSafe: false,
      forcedType: 'movie',
    );

    final unsafeRatedMovie = Channel(
      name: 'Animación Oscura 18+',
      url: 'catalog://movie-dark-anime',
      catalogTitleId: 'movie-dark-anime',
      genre: 'Animación',
      rating: 'TV-MA',
      isKidsSafe: true, // Error de etiquetado: dice kidsSafe pero tiene rating TV-MA
      forcedType: 'movie',
    );

    final kidsAdventureMovie = Channel(
      name: 'Buscando a Nemo',
      url: 'catalog://movie-nemo',
      catalogTitleId: 'movie-nemo',
      genre: 'Animación',
      rating: '8.2',
      isKidsSafe: true,
      forcedType: 'movie',
    );

    test('1. Filtro dual para perfil infantil excluye contenido sin isKidsSafe o con marcas para adultos', () async {
      final candidates = [
        kidsSafeMovie,
        regularActionMovie,
        unsafeRatedMovie,
        kidsAdventureMovie,
      ];

      final recs = await engine.getRecommendations(
        profileId: 'kids-profile-1',
        isKids: true,
        catalog: candidates,
      );

      // Solo deben incluirse kidsSafeMovie y kidsAdventureMovie
      expect(recs.any((r) => r.channel.catalogTitleId == 'movie-john-wick'), isFalse);
      expect(recs.any((r) => r.channel.catalogTitleId == 'movie-dark-anime'), isFalse);
      expect(recs.any((r) => r.channel.catalogTitleId == 'movie-toy-story'), isTrue);
      expect(recs.any((r) => r.channel.catalogTitleId == 'movie-nemo'), isTrue);
    });

    test('2. Perfil infantil retorna fallback vacio si no hay contenido seguro garantizado', () async {
      final candidates = [
        regularActionMovie,
        unsafeRatedMovie,
      ];

      final recs = await engine.getRecommendations(
        profileId: 'kids-profile-2',
        isKids: true,
        catalog: candidates,
      );

      expect(recs, isEmpty);
    });

    test('3. Recomienda con razon explicable basada en historial de reproduccion', () async {
      final now = DateTime.utc(2026, 9, 12, 12, 0, 0);

      // Registrar historial de visualización de una película de Acción
      await dao.addHistoryEntry(
        id: 'hist-1',
        profileId: 'adult-profile-1',
        playbackSessionId: 'sess-1',
        contentKey: 'movie:mission-impossible',
        titleId: 'movie-mi',
        stoppedAtMs: 500000,
        durationMs: 600000,
        fraction: 0.83,
        isCompleted: false,
        watchedAt: now,
      );

      final watchedChannel = Channel(
        name: 'Misión Imposible',
        url: 'catalog://movie-mi',
        catalogTitleId: 'movie-mi',
        genre: 'Acción',
        forcedType: 'movie',
      );

      final recommendedAction = Channel(
        name: 'Mad Max Furia',
        url: 'catalog://movie-mad-max',
        catalogTitleId: 'movie-mad-max',
        genre: 'Acción',
        rating: '8.6',
        forcedType: 'movie',
      );

      final candidates = [watchedChannel, recommendedAction, kidsSafeMovie];

      final recs = await engine.getRecommendations(
        profileId: 'adult-profile-1',
        isKids: false,
        catalog: candidates,
      );

      final madMaxRec = recs.firstWhere((r) => r.channel.catalogTitleId == 'movie-mad-max');
      expect(madMaxRec.reason, contains('Acción'));
    });

    test('4. Recomienda con razon explicable basada en favoritos', () async {
      final now = DateTime.utc(2026, 9, 12, 13, 0, 0);

      // Registrar favorito
      await dao.setFavorite(
        profileId: 'adult-profile-2',
        contentKey: 'movie:toy-story',
        titleId: 'movie-toy-story',
        isFavorite: true,
        updatedAt: now,
      );

      final candidates = [kidsSafeMovie, kidsAdventureMovie, regularActionMovie];

      final recs = await engine.getRecommendations(
        profileId: 'adult-profile-2',
        isKids: false,
        catalog: candidates,
      );

      final nemoRec = recs.firstWhere((r) => r.channel.catalogTitleId == 'movie-nemo');
      expect(nemoRec.reason, contains('favoritos'));
    });

    test('5. En arranque en frio (sin historial ni favoritos) recomienda contenidos destacados', () async {
      final featuredMovie = Channel(
        name: 'Interstellar Destacado',
        url: 'catalog://movie-interstellar',
        catalogTitleId: 'movie-interstellar',
        genre: 'Ciencia Ficción',
        rating: '8.9',
        isFeatured: true,
        forcedType: 'movie',
      );

      final candidates = [featuredMovie, regularActionMovie];

      final recs = await engine.getRecommendations(
        profileId: 'cold-user',
        isKids: false,
        catalog: candidates,
      );

      expect(recs.isNotEmpty, isTrue);
      expect(recs.first.channel.catalogTitleId, equals('movie-interstellar'));
      expect(recs.first.reason, contains('Destacado'));
    });
  });
}
