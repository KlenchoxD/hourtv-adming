import 'package:drift/drift.dart';
import '../catalog_database.dart';
import '../tables/catalog_tables.dart';
import '../../services/catalog/catalog_dtos.dart';

import '../../mobile_ui/hourtv_genre_service.dart';

part 'catalog_dao.g.dart';

@DriftAccessor(tables: [
  LocalTitles,
  LocalGenres,
  LocalLanguages,
  LocalTitleGenres,
  LocalSeasons,
  LocalEpisodes,
  LocalSources,
  CatalogSyncStates,
])
class CatalogDao extends DatabaseAccessor<CatalogDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  /// Sanitiza un término de búsqueda para la tabla virtual SQLite FTS5.
  /// Normaliza acentos, elimina operadores booleanos y sintaxis FTS5,
  /// y añade comodines de prefijo a tokens alfanuméricos seguros.
  static String sanitizeFts5Query(String rawQuery) {
    if (rawQuery.trim().isEmpty) return '';
    final normalized = HourTvGenreService.normalize(rawQuery);
    final sanitizedText = normalized
        .replaceAll(RegExp(r'["*^(){}:+\-]'), ' ')
        .replaceAll(RegExp(r'\b(AND|OR|NOT|NEAR)\b', caseSensitive: false), ' ');
    final tokens = sanitizedText
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && RegExp(r'^[a-z0-9]+$').hasMatch(t))
        .take(10)
        .map((t) => t.length > 50 ? t.substring(0, 50) : t)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '$t*').join(' ');
  }

  // --- Operaciones de Títulos ---

  Future<void> upsertTitle(LocalTitlesCompanion title) async {
    await into(localTitles).insertOnConflictUpdate(title);

    final titleId = title.id.value;
    final normalized = title.normalizedTitle.value;
    final original = title.originalTitle.value;
    final plot = title.plot.value;

    await customStatement(
      'DELETE FROM local_titles_fts WHERE title_id = ?',
      [titleId],
    );

    if (title.isDeleted.present && title.isDeleted.value == true) {
      return;
    }

    await customStatement(
      'INSERT INTO local_titles_fts (title_id, normalized_title, original_title, plot) VALUES (?, ?, ?, ?)',
      [titleId, normalized, original ?? '', plot ?? ''],
    );
  }

  Future<void> upsertTitles(List<LocalTitlesCompanion> titles) async {
    await transaction(() async {
      for (final title in titles) {
        await upsertTitle(title);
      }
    });
  }

  Future<void> markTitleDeleted(String titleId) async {
    await (update(localTitles)..where((t) => t.id.equals(titleId)))
        .write(const LocalTitlesCompanion(isDeleted: Value(true)));

    await customStatement(
      'DELETE FROM local_titles_fts WHERE title_id = ?',
      [titleId],
    );
  }

  Future<void> deleteTitle(String titleId) async {
    await (delete(localTitles)..where((t) => t.id.equals(titleId))).go();
    await customStatement(
      'DELETE FROM local_titles_fts WHERE title_id = ?',
      [titleId],
    );
  }

  Future<LocalTitle?> getTitleById(String id) {
    return (select(localTitles)..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<List<LocalTitle>> getTitlesByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(localTitles)..where((t) => t.id.isIn(ids) & t.isDeleted.equals(false)))
        .get();
  }

  /// Consulta paginada determinista basada en tupla (createdAt DESC, id DESC) o según sort order.
  Future<List<LocalTitle>> getPage({
    int limit = 20,
    DateTime? cursorCreatedAt,
    String? cursorId,
    String? mediaType,
    int? year,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) async {
    final query = select(localTitles);

    query.where((t) => t.isDeleted.equals(false));

    if (mediaType != null) {
      query.where((t) => t.mediaType.equals(mediaType));
    }

    if (year != null) {
      query.where((t) => t.year.equals(year));
    }

    if (genreSlug != null) {
      // Filtrar por relación con género
      query.where((t) => t.id.isInQuery(
            selectOnly(localTitleGenres)
              ..join([
                innerJoin(localGenres, localGenres.id.equalsExp(localTitleGenres.genreId)),
              ])
              ..where(localGenres.slug.equals(genreSlug))
              ..addColumns([localTitleGenres.titleId]),
          ));
    }

    // Condición determinista de cursor compuesto
    if (cursorCreatedAt != null && cursorId != null) {
      query.where((t) =>
          t.createdAt.isSmallerThanValue(cursorCreatedAt) |
          (t.createdAt.equals(cursorCreatedAt) & t.id.isSmallerThanValue(cursorId)));
    }

    switch (sort) {
      case CatalogSortOrder.recent:
        query.orderBy([
          (t) => OrderingTerm.desc(t.createdAt),
          (t) => OrderingTerm.desc(t.id),
        ]);
        break;
      case CatalogSortOrder.ratingDesc:
        query.orderBy([
          (t) => OrderingTerm.desc(t.rating),
          (t) => OrderingTerm.desc(t.id),
        ]);
        break;
      case CatalogSortOrder.titleAsc:
        query.orderBy([
          (t) => OrderingTerm.asc(t.normalizedTitle),
          (t) => OrderingTerm.asc(t.id),
        ]);
        break;
    }

    query.limit(limit);

    return query.get();
  }

  Future<List<LocalTitle>> getFeatured({int limit = 10}) {
    return (select(localTitles)
          ..where((t) => t.isFeatured.equals(true) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt), (t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
  }

  /// Búsqueda indexada FTS5 sanitizada y parametrizada
  Future<List<LocalTitle>> search({
    required String query,
    int limit = 20,
    DateTime? cursorCreatedAt,
    String? cursorId,
  }) async {
    final sanitized = sanitizeFts5Query(query);
    if (sanitized.isEmpty) {
      return [];
    }

    final rows = await customSelect(
      '''
      SELECT t.* FROM local_titles t
      JOIN local_titles_fts fts ON fts.title_id = t.id
      WHERE t.is_deleted = 0 AND local_titles_fts MATCH :matchQuery
      ORDER BY fts.rank ASC, t.created_at DESC, t.id DESC
      LIMIT :limit
      ''',
      variables: [
        Variable.withString(sanitized),
        Variable.withInt(limit),
      ],
      readsFrom: {localTitles},
    ).get();

    return rows.map((row) => localTitles.map(row.data)).toList();
  }

  // --- Operaciones de Sincronización y Revisiones ---

  Future<int> getLastCatalogRevision({String syncKey = 'default_sync'}) async {
    final state = await (select(catalogSyncStates)
          ..where((s) => s.syncKey.equals(syncKey)))
        .getSingleOrNull();

    return state?.lastCatalogRevision ?? 0;
  }

  Future<void> setLastCatalogRevision(int revision, {String syncKey = 'default_sync'}) async {
    await into(catalogSyncStates).insertOnConflictUpdate(
      CatalogSyncStatesCompanion.insert(
        syncKey: syncKey,
        lastCatalogRevision: Value(revision),
        lastSyncTimestamp: DateTime.now(),
      ),
    );
  }

  // --- Géneros e Idiomas ---

  Future<void> upsertGenre(LocalGenresCompanion genre) async {
    await into(localGenres).insertOnConflictUpdate(genre);
  }

  Future<void> deleteGenre(String genreId) async {
    await (delete(localGenres)..where((g) => g.id.equals(genreId))).go();
  }

  Future<List<LocalGenre>> getAllGenres() => select(localGenres).get();

  Future<void> upsertLanguage(LocalLanguagesCompanion language) async {
    await into(localLanguages).insertOnConflictUpdate(language);
  }

  Future<void> deleteLanguage(String langId) async {
    await (delete(localLanguages)..where((l) => l.id.equals(langId))).go();
  }

  Future<void> upsertTitleGenre(String titleId, String genreId) async {
    await into(localTitleGenres).insertOnConflictUpdate(
      LocalTitleGenresCompanion.insert(titleId: titleId, genreId: genreId),
    );
  }

  Future<void> deleteTitleGenre(String titleId, String genreId) async {
    await (delete(localTitleGenres)
          ..where((tg) => tg.titleId.equals(titleId) & tg.genreId.equals(genreId)))
        .go();
  }

  Future<List<LocalGenre>> getGenresForTitle(String titleId) {
    final query = select(localGenres).join([
      innerJoin(localTitleGenres, localTitleGenres.genreId.equalsExp(localGenres.id)),
    ])..where(localTitleGenres.titleId.equals(titleId));

    return query.map((row) => row.readTable(localGenres)).get();
  }

  // --- Temporadas, Episodios y Fuentes ---

  Future<void> upsertSeason(LocalSeasonsCompanion season) async {
    await into(localSeasons).insertOnConflictUpdate(season);
  }

  Future<void> deleteSeason(String seasonId) async {
    await (delete(localSeasons)..where((s) => s.id.equals(seasonId))).go();
  }

  Future<List<LocalSeason>> getSeasonsForTitle(String titleId) {
    return (select(localSeasons)
          ..where((s) => s.titleId.equals(titleId) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.seasonNumber)]))
        .get();
  }

  Future<void> upsertEpisode(LocalEpisodesCompanion episode) async {
    await into(localEpisodes).insertOnConflictUpdate(episode);
  }

  Future<void> deleteEpisode(String episodeId) async {
    await (delete(localEpisodes)..where((e) => e.id.equals(episodeId))).go();
  }

  Future<List<LocalEpisode>> getEpisodesForSeason(String seasonId) {
    return (select(localEpisodes)
          ..where((e) => e.seasonId.equals(seasonId) & e.isDeleted.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.episodeNumber)]))
        .get();
  }

  Future<void> upsertSource(LocalSourcesCompanion source) async {
    await into(localSources).insertOnConflictUpdate(source);
  }

  Future<void> deleteSource(String sourceId) async {
    await (delete(localSources)..where((s) => s.id.equals(sourceId))).go();
  }

  Future<List<LocalSource>> getSourcesForTitle(String titleId) {
    return (select(localSources)
          ..where((s) => s.titleId.equals(titleId) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.orderIndex)]))
        .get();
  }

  Future<List<LocalSource>> getSourcesForEpisode(String episodeId) {
    return (select(localSources)
          ..where((s) => s.episodeId.equals(episodeId) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.orderIndex)]))
        .get();
  }

  Future<void> linkTitleGenres(List<LocalTitleGenresCompanion> links) async {
    await transaction(() async {
      for (final link in links) {
        await into(localTitleGenres).insertOnConflictUpdate(link);
      }
    });
  }

  Future<void> unlinkTitleGenre(String titleId, String genreId) async {
    await (delete(localTitleGenres)
          ..where((tg) => tg.titleId.equals(titleId) & tg.genreId.equals(genreId)))
        .go();
  }

  Future<void> upsertGenres(List<LocalGenresCompanion> genres) async {
    await transaction(() async {
      for (final g in genres) {
        await into(localGenres).insertOnConflictUpdate(g);
      }
    });
  }

  Future<void> upsertLanguages(List<LocalLanguagesCompanion> languages) async {
    await transaction(() async {
      for (final l in languages) {
        await into(localLanguages).insertOnConflictUpdate(l);
      }
    });
  }

  /// Aplica una lápida (tombstone) a la entidad correspondiente.
  Future<void> applyTombstone(String entityType, String entityId) async {
    switch (entityType) {
      case 'title':
        await markTitleDeleted(entityId);
        break;
      case 'title_genre':
        final parts = entityId.split(':');
        if (parts.length == 2) {
          await unlinkTitleGenre(parts[0], parts[1]);
        }
        break;
      case 'source':
        await deleteSource(entityId);
        break;
      case 'episode':
        await deleteEpisode(entityId);
        break;
      case 'season':
        await deleteSeason(entityId);
        break;
      case 'genre':
        await deleteGenre(entityId);
        break;
      case 'language':
        await deleteLanguage(entityId);
        break;
    }
  }

  /// Búsqueda por FTS5 con soporte completo de filtros por tipo, género y orden.
  Future<List<LocalTitle>> searchTitlesFts({
    required String rawQuery,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
    int limit = 20,
  }) async {
    final sanitized = sanitizeFts5Query(rawQuery);
    if (sanitized.isEmpty) return [];

    final whereClauses = <String>[
      't.is_deleted = 0',
      'local_titles_fts MATCH :matchQuery',
    ];
    final variables = <Variable>[
      Variable.withString(sanitized),
    ];

    if (mediaType != null && mediaType.isNotEmpty && mediaType != 'all') {
      whereClauses.add('t.media_type = :mediaType');
      variables.add(Variable.withString(mediaType));
    }

    if (genreSlug != null && genreSlug.isNotEmpty && genreSlug != 'all') {
      whereClauses.add('''
        t.id IN (
          SELECT tg.title_id FROM local_title_genres tg
          JOIN local_genres g ON g.id = tg.genre_id
          WHERE g.slug = :genreSlug
        )
      ''');
      variables.add(Variable.withString(genreSlug));
    }

    String orderByClause;
    switch (sort) {
      case CatalogSortOrder.recent:
        orderByClause = 't.created_at DESC, t.id DESC';
        break;
      case CatalogSortOrder.ratingDesc:
        orderByClause = 't.rating DESC, t.id DESC';
        break;
      case CatalogSortOrder.titleAsc:
        orderByClause = 't.normalized_title ASC, t.id ASC';
        break;
    }

    final sql = '''
      SELECT t.* FROM local_titles t
      JOIN local_titles_fts fts ON fts.title_id = t.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY $orderByClause
      LIMIT :limit
    ''';
    variables.add(Variable.withInt(limit));

    final rows = await customSelect(
      sql,
      variables: variables,
      readsFrom: {localTitles},
    ).get();

    return rows.map((row) => localTitles.map(row.data)).toList();
  }

  /// Aplica de forma atómica un lote de sincronización delta junto con el nuevo checkpoint de revisión.
  /// Si cualquier operación falla, la transacción se revierte por completo y la revisión no avanza.
  Future<void> applySyncBatchAtomic({
    required Future<void> Function(CatalogDao txDao) operations,
    required int newRevision,
    required DateTime timestamp,
    String syncKey = 'default_sync',
  }) async {
    await transaction(() async {
      await operations(this);
      await into(catalogSyncStates).insertOnConflictUpdate(
        CatalogSyncStatesCompanion.insert(
          syncKey: syncKey,
          lastCatalogRevision: Value(newRevision),
          lastSyncTimestamp: timestamp,
        ),
      );
    });
  }

  /// Limpieza transaccional completa del catálogo local (usada para resincronización completa tras compactación).
  /// NO borra favoritos ni historial de reproducción del usuario.
  Future<void> clearAllCatalog() async {
    await transaction(() async {
      await delete(localSources).go();
      await delete(localEpisodes).go();
      await delete(localSeasons).go();
      await delete(localTitleGenres).go();
      await delete(localTitles).go();
      await delete(localGenres).go();
      await delete(localLanguages).go();
      await customStatement('DELETE FROM local_titles_fts;');
    });
  }
}
