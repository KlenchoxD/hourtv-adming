import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'tables/catalog_tables.dart';
import 'tables/user_data_tables.dart';
import 'daos/catalog_dao.dart';
import 'daos/user_data_dao.dart';

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
    LocalProfileFavorites,
    LocalProfilePlaybackProgress,
    LocalProfileHistory,
    LocalProfilePreferences,
    LocalProfileSyncQueue,
    LocalProfileSyncCheckpoint,
    LocalGuestImportAudit,
  ],
  daos: [CatalogDao, UserDataDao],
)
class CatalogDatabase extends _$CatalogDatabase {
  CatalogDatabase(super.e);

  CatalogDatabase.inMemory() : super(NativeDatabase.memory());

  factory CatalogDatabase.inBackground(File file) {
    return CatalogDatabase(NativeDatabase.createInBackground(file));
  }

  @override
  int get schemaVersion => 3;

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
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(localProfileFavorites);
        await m.createTable(localProfilePlaybackProgress);
        await m.createTable(localProfileHistory);
        await m.createTable(localProfilePreferences);
        await m.createTable(localProfileSyncQueue);
        await m.createTable(localProfileSyncCheckpoint);
        await m.createTable(localGuestImportAudit);
        await _createIndices();
      }
      if (from < 3) {
        await m.addColumn(localSources, localSources.healthStatus);
        await m.addColumn(localSources, localSources.healthLastError);
        await m.addColumn(localSources, localSources.healthHttpCode);
        await m.addColumn(localSources, localSources.healthConsecutiveFailures);
        await m.addColumn(localSources, localSources.healthFirstFailureAt);
        await m.addColumn(localSources, localSources.healthLastSuccessAt);
        await m.addColumn(localSources, localSources.healthLastCheck);
        await m.addColumn(localSources, localSources.healthLastCheckRunId);
      }
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

    // Índices de Datos de Usuario y Sincronización
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_favorites_profile_fav ON local_profile_favorites(profile_id, is_favorite, updated_at DESC);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_progress_continue ON local_profile_playback_progress(profile_id, is_completed, last_watched_at DESC);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_history_timeline ON local_profile_history(profile_id, watched_at DESC);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_sync_queue_order ON local_profile_sync_queue(profile_id, status, client_sequence ASC);',
    );
  }
}
