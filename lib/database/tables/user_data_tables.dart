import 'package:drift/drift.dart';

// Tablas de Datos de Usuario y Sincronización para Drift (SQLite)

class LocalProfileFavorites extends Table {
  TextColumn get profileId => text()();
  TextColumn get contentKey => text()();
  TextColumn get titleId => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {profileId, contentKey};
}

class LocalProfilePlaybackProgress extends Table {
  TextColumn get profileId => text()();
  TextColumn get contentKey => text()();
  TextColumn get playbackSessionId => text().nullable()();
  TextColumn get titleId => text().nullable()();
  TextColumn get episodeId => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  RealColumn get fraction => real().withDefault(const Constant(0.0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastWatchedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {profileId, contentKey};
}

class LocalProfileHistory extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get playbackSessionId => text()();
  TextColumn get contentKey => text()();
  TextColumn get titleId => text().nullable()();
  TextColumn get episodeId => text().nullable()();
  IntColumn get stoppedAtMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  RealColumn get fraction => real().withDefault(const Constant(0.0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get watchedAt => dateTime()();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalProfilePreferences extends Table {
  TextColumn get profileId => text()();
  TextColumn get preferredAudioLanguage => text().nullable()();
  TextColumn get preferredSubtitleLanguage => text().nullable()();
  BoolColumn get subtitlesEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get autoPlayNext => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {profileId};
}

class LocalProfileSyncQueue extends Table {
  TextColumn get operationId => text()();
  TextColumn get profileId => text()();
  TextColumn get deviceId => text()();
  IntColumn get clientSequence => integer()();
  TextColumn get playbackSessionId => text().nullable()();
  TextColumn get operationType => text()(); // favorite_add, favorite_remove, progress_update, restart, etc.
  TextColumn get contentKey => text()();
  TextColumn get titleId => text().nullable()();
  TextColumn get episodeId => text().nullable()();
  TextColumn get payload => text().withDefault(const Constant('{}'))(); // JSON payload
  DateTimeColumn get clientTimestamp => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_flight, applied, failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {operationId};
}

class LocalProfileSyncCheckpoint extends Table {
  TextColumn get profileId => text()();
  IntColumn get latestServerRevision => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  IntColumn get lastSuccessfulSequence => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {profileId};
}

class LocalGuestImportAudit extends Table {
  TextColumn get id => text()();
  TextColumn get targetProfileId => text()();
  TextColumn get importBatchId => text()();
  TextColumn get status => text()(); // in_progress, completed, failed
  IntColumn get favoritesCount => integer().withDefault(const Constant(0))();
  IntColumn get progressCount => integer().withDefault(const Constant(0))();
  IntColumn get historyCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
