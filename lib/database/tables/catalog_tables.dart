import 'package:drift/drift.dart';

// Tablas del Catálogo Local para Drift (SQLite)

class LocalTitles extends Table {
  TextColumn get id => text()();
  TextColumn get legacyId => text().nullable()();
  TextColumn get mediaType => text()();
  TextColumn get title => text()();
  TextColumn get originalTitle => text().nullable()();
  TextColumn get normalizedTitle => text()();
  TextColumn get plot => text().nullable()();
  IntColumn get year => integer().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get duration => text().nullable()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  BoolColumn get isFeatured => boolean().withDefault(const Constant(false))();
  TextColumn get castMembers => text().nullable()();
  TextColumn get director => text().nullable()();
  TextColumn get writer => text().nullable()();
  TextColumn get countryCode => text().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  TextColumn get imdbId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalGenres extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get slug => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalLanguages extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalTitleGenres extends Table {
  TextColumn get titleId =>
      text().references(LocalTitles, #id, onDelete: KeyAction.cascade)();
  TextColumn get genreId =>
      text().references(LocalGenres, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {titleId, genreId};
}

class LocalSeasons extends Table {
  TextColumn get id => text()();
  TextColumn get titleId =>
      text().references(LocalTitles, #id, onDelete: KeyAction.cascade)();
  IntColumn get seasonNumber => integer()();
  TextColumn get name => text().nullable()();
  TextColumn get plot => text().nullable()();
  TextColumn get posterUrl => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalEpisodes extends Table {
  TextColumn get id => text()();
  TextColumn get seasonId =>
      text().references(LocalSeasons, #id, onDelete: KeyAction.cascade)();
  IntColumn get episodeNumber => integer()();
  TextColumn get title => text()();
  TextColumn get plot => text().nullable()();
  TextColumn get duration => text().nullable()();
  TextColumn get stillUrl => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSources extends Table {
  TextColumn get id => text()();
  TextColumn get titleId => text().nullable().references(
    LocalTitles,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get episodeId => text().nullable().references(
    LocalEpisodes,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get name => text()();
  TextColumn get url => text()();
  TextColumn get language => text().nullable()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get requiresWebview =>
      boolean().withDefault(const Constant(false))();
  TextColumn get refererUrl => text().nullable()();
  TextColumn get originUrl => text().nullable()();
  TextColumn get userAgentProfile => text().nullable()();

  TextColumn get healthStatus =>
      text().withDefault(const Constant('pending'))();
  TextColumn get healthLastError => text().nullable()();
  IntColumn get healthHttpCode => integer().nullable()();
  IntColumn get healthConsecutiveFailures =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get healthFirstFailureAt => dateTime().nullable()();
  DateTimeColumn get healthLastSuccessAt => dateTime().nullable()();
  DateTimeColumn get healthLastCheck => dateTime().nullable()();
  TextColumn get healthLastCheckRunId => text().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogSyncStates extends Table {
  TextColumn get syncKey => text()();
  // IntColumn en Drift mapea a int de Dart (64-bit integer), soportando revisiones > 2^31
  IntColumn get lastCatalogRevision =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncTimestamp => dateTime()();
  IntColumn get totalSynced => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {syncKey};
}
