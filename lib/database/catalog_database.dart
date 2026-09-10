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
    },
  );
}
