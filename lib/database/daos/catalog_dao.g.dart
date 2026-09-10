// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_dao.dart';

// ignore_for_file: type=lint
mixin _$CatalogDaoMixin on DatabaseAccessor<CatalogDatabase> {
  $LocalTitlesTable get localTitles => attachedDatabase.localTitles;
  $LocalGenresTable get localGenres => attachedDatabase.localGenres;
  $LocalLanguagesTable get localLanguages => attachedDatabase.localLanguages;
  $LocalTitleGenresTable get localTitleGenres =>
      attachedDatabase.localTitleGenres;
  $LocalSeasonsTable get localSeasons => attachedDatabase.localSeasons;
  $LocalEpisodesTable get localEpisodes => attachedDatabase.localEpisodes;
  $LocalSourcesTable get localSources => attachedDatabase.localSources;
  $CatalogSyncStatesTable get catalogSyncStates =>
      attachedDatabase.catalogSyncStates;
  CatalogDaoManager get managers => CatalogDaoManager(this);
}

class CatalogDaoManager {
  final _$CatalogDaoMixin _db;
  CatalogDaoManager(this._db);
  $$LocalTitlesTableTableManager get localTitles =>
      $$LocalTitlesTableTableManager(_db.attachedDatabase, _db.localTitles);
  $$LocalGenresTableTableManager get localGenres =>
      $$LocalGenresTableTableManager(_db.attachedDatabase, _db.localGenres);
  $$LocalLanguagesTableTableManager get localLanguages =>
      $$LocalLanguagesTableTableManager(
        _db.attachedDatabase,
        _db.localLanguages,
      );
  $$LocalTitleGenresTableTableManager get localTitleGenres =>
      $$LocalTitleGenresTableTableManager(
        _db.attachedDatabase,
        _db.localTitleGenres,
      );
  $$LocalSeasonsTableTableManager get localSeasons =>
      $$LocalSeasonsTableTableManager(_db.attachedDatabase, _db.localSeasons);
  $$LocalEpisodesTableTableManager get localEpisodes =>
      $$LocalEpisodesTableTableManager(_db.attachedDatabase, _db.localEpisodes);
  $$LocalSourcesTableTableManager get localSources =>
      $$LocalSourcesTableTableManager(_db.attachedDatabase, _db.localSources);
  $$CatalogSyncStatesTableTableManager get catalogSyncStates =>
      $$CatalogSyncStatesTableTableManager(
        _db.attachedDatabase,
        _db.catalogSyncStates,
      );
}
