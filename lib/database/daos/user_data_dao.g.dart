// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data_dao.dart';

// ignore_for_file: type=lint
mixin _$UserDataDaoMixin on DatabaseAccessor<CatalogDatabase> {
  $LocalProfileFavoritesTable get localProfileFavorites =>
      attachedDatabase.localProfileFavorites;
  $LocalProfilePlaybackProgressTable get localProfilePlaybackProgress =>
      attachedDatabase.localProfilePlaybackProgress;
  $LocalProfileHistoryTable get localProfileHistory =>
      attachedDatabase.localProfileHistory;
  $LocalProfilePreferencesTable get localProfilePreferences =>
      attachedDatabase.localProfilePreferences;
  $LocalProfileSyncQueueTable get localProfileSyncQueue =>
      attachedDatabase.localProfileSyncQueue;
  $LocalProfileSyncCheckpointTable get localProfileSyncCheckpoint =>
      attachedDatabase.localProfileSyncCheckpoint;
  $LocalGuestImportAuditTable get localGuestImportAudit =>
      attachedDatabase.localGuestImportAudit;
  $LocalTitlesTable get localTitles => attachedDatabase.localTitles;
  $LocalSeasonsTable get localSeasons => attachedDatabase.localSeasons;
  $LocalEpisodesTable get localEpisodes => attachedDatabase.localEpisodes;
  UserDataDaoManager get managers => UserDataDaoManager(this);
}

class UserDataDaoManager {
  final _$UserDataDaoMixin _db;
  UserDataDaoManager(this._db);
  $$LocalProfileFavoritesTableTableManager get localProfileFavorites =>
      $$LocalProfileFavoritesTableTableManager(
        _db.attachedDatabase,
        _db.localProfileFavorites,
      );
  $$LocalProfilePlaybackProgressTableTableManager
  get localProfilePlaybackProgress =>
      $$LocalProfilePlaybackProgressTableTableManager(
        _db.attachedDatabase,
        _db.localProfilePlaybackProgress,
      );
  $$LocalProfileHistoryTableTableManager get localProfileHistory =>
      $$LocalProfileHistoryTableTableManager(
        _db.attachedDatabase,
        _db.localProfileHistory,
      );
  $$LocalProfilePreferencesTableTableManager get localProfilePreferences =>
      $$LocalProfilePreferencesTableTableManager(
        _db.attachedDatabase,
        _db.localProfilePreferences,
      );
  $$LocalProfileSyncQueueTableTableManager get localProfileSyncQueue =>
      $$LocalProfileSyncQueueTableTableManager(
        _db.attachedDatabase,
        _db.localProfileSyncQueue,
      );
  $$LocalProfileSyncCheckpointTableTableManager
  get localProfileSyncCheckpoint =>
      $$LocalProfileSyncCheckpointTableTableManager(
        _db.attachedDatabase,
        _db.localProfileSyncCheckpoint,
      );
  $$LocalGuestImportAuditTableTableManager get localGuestImportAudit =>
      $$LocalGuestImportAuditTableTableManager(
        _db.attachedDatabase,
        _db.localGuestImportAudit,
      );
  $$LocalTitlesTableTableManager get localTitles =>
      $$LocalTitlesTableTableManager(_db.attachedDatabase, _db.localTitles);
  $$LocalSeasonsTableTableManager get localSeasons =>
      $$LocalSeasonsTableTableManager(_db.attachedDatabase, _db.localSeasons);
  $$LocalEpisodesTableTableManager get localEpisodes =>
      $$LocalEpisodesTableTableManager(_db.attachedDatabase, _db.localEpisodes);
}
