import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'tables/catalog_tables.dart';
import 'daos/catalog_dao.dart';

part 'catalog_database.g.dart';

@DriftDatabase(
  tables: [
    LocalTitles,
    LocalGenres,
    LocalLanguages,
    LocalTitleGenres,
    LocalSeasons,
    LocalEpisodes,
    LocalSources,
    CatalogSyncStates,
  ],
  daos: [CatalogDao],
)
class CatalogDatabase extends _$CatalogDatabase {
  CatalogDatabase(super.e);

  CatalogDatabase.inMemory() : super(NativeDatabase.memory());

  factory CatalogDatabase.inBackground(File file) {
    return CatalogDatabase(NativeDatabase.createInBackground(file));
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // Crear tabla virtual FTS5 para búsquedas ultrarrápidas y sin diacríticos
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS local_titles_fts USING fts5(
          title_id UNINDEXED,
          normalized_title,
          original_title,
          plot,
          tokenize='unicode61 remove_diacritics 2'
        );
      ''');
      await _createIndices();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await _createIndices();
    },
  );

  Future<void> _createIndices() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_titles_cursor ON local_titles(is_deleted, created_at DESC, id DESC);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_titles_media_cursor ON local_titles(is_deleted, media_type, created_at DESC, id DESC);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_titles_year_id ON local_titles(year, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_title_genres_genre ON local_title_genres(genre_id, title_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_seasons_title ON local_seasons(title_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_episodes_season ON local_episodes(season_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sources_title ON local_sources(title_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sources_episode ON local_sources(episode_id);',
    );
  }
}
