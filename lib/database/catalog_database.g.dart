// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_database.dart';

// ignore_for_file: type=lint
class $LocalTitlesTable extends LocalTitles
    with TableInfo<$LocalTitlesTable, LocalTitle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTitlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<String> legacyId = GeneratedColumn<String>(
    'legacy_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalTitleMeta = const VerificationMeta(
    'originalTitle',
  );
  @override
  late final GeneratedColumn<String> originalTitle = GeneratedColumn<String>(
    'original_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _normalizedTitleMeta = const VerificationMeta(
    'normalizedTitle',
  );
  @override
  late final GeneratedColumn<String> normalizedTitle = GeneratedColumn<String>(
    'normalized_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<String> duration = GeneratedColumn<String>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterUrlMeta = const VerificationMeta(
    'posterUrl',
  );
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
    'poster_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropUrlMeta = const VerificationMeta(
    'backdropUrl',
  );
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
    'backdrop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFeaturedMeta = const VerificationMeta(
    'isFeatured',
  );
  @override
  late final GeneratedColumn<bool> isFeatured = GeneratedColumn<bool>(
    'is_featured',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_featured" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _castMembersMeta = const VerificationMeta(
    'castMembers',
  );
  @override
  late final GeneratedColumn<String> castMembers = GeneratedColumn<String>(
    'cast_members',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directorMeta = const VerificationMeta(
    'director',
  );
  @override
  late final GeneratedColumn<String> director = GeneratedColumn<String>(
    'director',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _writerMeta = const VerificationMeta('writer');
  @override
  late final GeneratedColumn<String> writer = GeneratedColumn<String>(
    'writer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imdbIdMeta = const VerificationMeta('imdbId');
  @override
  late final GeneratedColumn<String> imdbId = GeneratedColumn<String>(
    'imdb_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    legacyId,
    mediaType,
    title,
    originalTitle,
    normalizedTitle,
    plot,
    year,
    rating,
    duration,
    posterUrl,
    backdropUrl,
    isFeatured,
    castMembers,
    director,
    writer,
    countryCode,
    tmdbId,
    imdbId,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_titles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTitle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
      );
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('original_title')) {
      context.handle(
        _originalTitleMeta,
        originalTitle.isAcceptableOrUnknown(
          data['original_title']!,
          _originalTitleMeta,
        ),
      );
    }
    if (data.containsKey('normalized_title')) {
      context.handle(
        _normalizedTitleMeta,
        normalizedTitle.isAcceptableOrUnknown(
          data['normalized_title']!,
          _normalizedTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedTitleMeta);
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('poster_url')) {
      context.handle(
        _posterUrlMeta,
        posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta),
      );
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
        _backdropUrlMeta,
        backdropUrl.isAcceptableOrUnknown(
          data['backdrop_url']!,
          _backdropUrlMeta,
        ),
      );
    }
    if (data.containsKey('is_featured')) {
      context.handle(
        _isFeaturedMeta,
        isFeatured.isAcceptableOrUnknown(data['is_featured']!, _isFeaturedMeta),
      );
    }
    if (data.containsKey('cast_members')) {
      context.handle(
        _castMembersMeta,
        castMembers.isAcceptableOrUnknown(
          data['cast_members']!,
          _castMembersMeta,
        ),
      );
    }
    if (data.containsKey('director')) {
      context.handle(
        _directorMeta,
        director.isAcceptableOrUnknown(data['director']!, _directorMeta),
      );
    }
    if (data.containsKey('writer')) {
      context.handle(
        _writerMeta,
        writer.isAcceptableOrUnknown(data['writer']!, _writerMeta),
      );
    }
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    if (data.containsKey('imdb_id')) {
      context.handle(
        _imdbIdMeta,
        imdbId.isAcceptableOrUnknown(data['imdb_id']!, _imdbIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTitle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTitle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}legacy_id'],
      ),
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      originalTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_title'],
      ),
      normalizedTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_title'],
      )!,
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duration'],
      ),
      posterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_url'],
      ),
      backdropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_url'],
      ),
      isFeatured: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_featured'],
      )!,
      castMembers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast_members'],
      ),
      director: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}director'],
      ),
      writer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}writer'],
      ),
      countryCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country_code'],
      ),
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_id'],
      ),
      imdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imdb_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $LocalTitlesTable createAlias(String alias) {
    return $LocalTitlesTable(attachedDatabase, alias);
  }
}

class LocalTitle extends DataClass implements Insertable<LocalTitle> {
  final String id;
  final String? legacyId;
  final String mediaType;
  final String title;
  final String? originalTitle;
  final String normalizedTitle;
  final String? plot;
  final int? year;
  final double? rating;
  final String? duration;
  final String? posterUrl;
  final String? backdropUrl;
  final bool isFeatured;
  final String? castMembers;
  final String? director;
  final String? writer;
  final String? countryCode;
  final int? tmdbId;
  final String? imdbId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const LocalTitle({
    required this.id,
    this.legacyId,
    required this.mediaType,
    required this.title,
    this.originalTitle,
    required this.normalizedTitle,
    this.plot,
    this.year,
    this.rating,
    this.duration,
    this.posterUrl,
    this.backdropUrl,
    required this.isFeatured,
    this.castMembers,
    this.director,
    this.writer,
    this.countryCode,
    this.tmdbId,
    this.imdbId,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || legacyId != null) {
      map['legacy_id'] = Variable<String>(legacyId);
    }
    map['media_type'] = Variable<String>(mediaType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || originalTitle != null) {
      map['original_title'] = Variable<String>(originalTitle);
    }
    map['normalized_title'] = Variable<String>(normalizedTitle);
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<String>(duration);
    }
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    map['is_featured'] = Variable<bool>(isFeatured);
    if (!nullToAbsent || castMembers != null) {
      map['cast_members'] = Variable<String>(castMembers);
    }
    if (!nullToAbsent || director != null) {
      map['director'] = Variable<String>(director);
    }
    if (!nullToAbsent || writer != null) {
      map['writer'] = Variable<String>(writer);
    }
    if (!nullToAbsent || countryCode != null) {
      map['country_code'] = Variable<String>(countryCode);
    }
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    if (!nullToAbsent || imdbId != null) {
      map['imdb_id'] = Variable<String>(imdbId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  LocalTitlesCompanion toCompanion(bool nullToAbsent) {
    return LocalTitlesCompanion(
      id: Value(id),
      legacyId: legacyId == null && nullToAbsent
          ? const Value.absent()
          : Value(legacyId),
      mediaType: Value(mediaType),
      title: Value(title),
      originalTitle: originalTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(originalTitle),
      normalizedTitle: Value(normalizedTitle),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      isFeatured: Value(isFeatured),
      castMembers: castMembers == null && nullToAbsent
          ? const Value.absent()
          : Value(castMembers),
      director: director == null && nullToAbsent
          ? const Value.absent()
          : Value(director),
      writer: writer == null && nullToAbsent
          ? const Value.absent()
          : Value(writer),
      countryCode: countryCode == null && nullToAbsent
          ? const Value.absent()
          : Value(countryCode),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
      imdbId: imdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(imdbId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory LocalTitle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTitle(
      id: serializer.fromJson<String>(json['id']),
      legacyId: serializer.fromJson<String?>(json['legacyId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      title: serializer.fromJson<String>(json['title']),
      originalTitle: serializer.fromJson<String?>(json['originalTitle']),
      normalizedTitle: serializer.fromJson<String>(json['normalizedTitle']),
      plot: serializer.fromJson<String?>(json['plot']),
      year: serializer.fromJson<int?>(json['year']),
      rating: serializer.fromJson<double?>(json['rating']),
      duration: serializer.fromJson<String?>(json['duration']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      isFeatured: serializer.fromJson<bool>(json['isFeatured']),
      castMembers: serializer.fromJson<String?>(json['castMembers']),
      director: serializer.fromJson<String?>(json['director']),
      writer: serializer.fromJson<String?>(json['writer']),
      countryCode: serializer.fromJson<String?>(json['countryCode']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
      imdbId: serializer.fromJson<String?>(json['imdbId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'legacyId': serializer.toJson<String?>(legacyId),
      'mediaType': serializer.toJson<String>(mediaType),
      'title': serializer.toJson<String>(title),
      'originalTitle': serializer.toJson<String?>(originalTitle),
      'normalizedTitle': serializer.toJson<String>(normalizedTitle),
      'plot': serializer.toJson<String?>(plot),
      'year': serializer.toJson<int?>(year),
      'rating': serializer.toJson<double?>(rating),
      'duration': serializer.toJson<String?>(duration),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'isFeatured': serializer.toJson<bool>(isFeatured),
      'castMembers': serializer.toJson<String?>(castMembers),
      'director': serializer.toJson<String?>(director),
      'writer': serializer.toJson<String?>(writer),
      'countryCode': serializer.toJson<String?>(countryCode),
      'tmdbId': serializer.toJson<int?>(tmdbId),
      'imdbId': serializer.toJson<String?>(imdbId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  LocalTitle copyWith({
    String? id,
    Value<String?> legacyId = const Value.absent(),
    String? mediaType,
    String? title,
    Value<String?> originalTitle = const Value.absent(),
    String? normalizedTitle,
    Value<String?> plot = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<String?> duration = const Value.absent(),
    Value<String?> posterUrl = const Value.absent(),
    Value<String?> backdropUrl = const Value.absent(),
    bool? isFeatured,
    Value<String?> castMembers = const Value.absent(),
    Value<String?> director = const Value.absent(),
    Value<String?> writer = const Value.absent(),
    Value<String?> countryCode = const Value.absent(),
    Value<int?> tmdbId = const Value.absent(),
    Value<String?> imdbId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => LocalTitle(
    id: id ?? this.id,
    legacyId: legacyId.present ? legacyId.value : this.legacyId,
    mediaType: mediaType ?? this.mediaType,
    title: title ?? this.title,
    originalTitle: originalTitle.present
        ? originalTitle.value
        : this.originalTitle,
    normalizedTitle: normalizedTitle ?? this.normalizedTitle,
    plot: plot.present ? plot.value : this.plot,
    year: year.present ? year.value : this.year,
    rating: rating.present ? rating.value : this.rating,
    duration: duration.present ? duration.value : this.duration,
    posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
    backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
    isFeatured: isFeatured ?? this.isFeatured,
    castMembers: castMembers.present ? castMembers.value : this.castMembers,
    director: director.present ? director.value : this.director,
    writer: writer.present ? writer.value : this.writer,
    countryCode: countryCode.present ? countryCode.value : this.countryCode,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
    imdbId: imdbId.present ? imdbId.value : this.imdbId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  LocalTitle copyWithCompanion(LocalTitlesCompanion data) {
    return LocalTitle(
      id: data.id.present ? data.id.value : this.id,
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      title: data.title.present ? data.title.value : this.title,
      originalTitle: data.originalTitle.present
          ? data.originalTitle.value
          : this.originalTitle,
      normalizedTitle: data.normalizedTitle.present
          ? data.normalizedTitle.value
          : this.normalizedTitle,
      plot: data.plot.present ? data.plot.value : this.plot,
      year: data.year.present ? data.year.value : this.year,
      rating: data.rating.present ? data.rating.value : this.rating,
      duration: data.duration.present ? data.duration.value : this.duration,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      backdropUrl: data.backdropUrl.present
          ? data.backdropUrl.value
          : this.backdropUrl,
      isFeatured: data.isFeatured.present
          ? data.isFeatured.value
          : this.isFeatured,
      castMembers: data.castMembers.present
          ? data.castMembers.value
          : this.castMembers,
      director: data.director.present ? data.director.value : this.director,
      writer: data.writer.present ? data.writer.value : this.writer,
      countryCode: data.countryCode.present
          ? data.countryCode.value
          : this.countryCode,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      imdbId: data.imdbId.present ? data.imdbId.value : this.imdbId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTitle(')
          ..write('id: $id, ')
          ..write('legacyId: $legacyId, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('plot: $plot, ')
          ..write('year: $year, ')
          ..write('rating: $rating, ')
          ..write('duration: $duration, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('isFeatured: $isFeatured, ')
          ..write('castMembers: $castMembers, ')
          ..write('director: $director, ')
          ..write('writer: $writer, ')
          ..write('countryCode: $countryCode, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('imdbId: $imdbId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    legacyId,
    mediaType,
    title,
    originalTitle,
    normalizedTitle,
    plot,
    year,
    rating,
    duration,
    posterUrl,
    backdropUrl,
    isFeatured,
    castMembers,
    director,
    writer,
    countryCode,
    tmdbId,
    imdbId,
    createdAt,
    updatedAt,
    isDeleted,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTitle &&
          other.id == this.id &&
          other.legacyId == this.legacyId &&
          other.mediaType == this.mediaType &&
          other.title == this.title &&
          other.originalTitle == this.originalTitle &&
          other.normalizedTitle == this.normalizedTitle &&
          other.plot == this.plot &&
          other.year == this.year &&
          other.rating == this.rating &&
          other.duration == this.duration &&
          other.posterUrl == this.posterUrl &&
          other.backdropUrl == this.backdropUrl &&
          other.isFeatured == this.isFeatured &&
          other.castMembers == this.castMembers &&
          other.director == this.director &&
          other.writer == this.writer &&
          other.countryCode == this.countryCode &&
          other.tmdbId == this.tmdbId &&
          other.imdbId == this.imdbId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class LocalTitlesCompanion extends UpdateCompanion<LocalTitle> {
  final Value<String> id;
  final Value<String?> legacyId;
  final Value<String> mediaType;
  final Value<String> title;
  final Value<String?> originalTitle;
  final Value<String> normalizedTitle;
  final Value<String?> plot;
  final Value<int?> year;
  final Value<double?> rating;
  final Value<String?> duration;
  final Value<String?> posterUrl;
  final Value<String?> backdropUrl;
  final Value<bool> isFeatured;
  final Value<String?> castMembers;
  final Value<String?> director;
  final Value<String?> writer;
  final Value<String?> countryCode;
  final Value<int?> tmdbId;
  final Value<String?> imdbId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const LocalTitlesCompanion({
    this.id = const Value.absent(),
    this.legacyId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.title = const Value.absent(),
    this.originalTitle = const Value.absent(),
    this.normalizedTitle = const Value.absent(),
    this.plot = const Value.absent(),
    this.year = const Value.absent(),
    this.rating = const Value.absent(),
    this.duration = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.isFeatured = const Value.absent(),
    this.castMembers = const Value.absent(),
    this.director = const Value.absent(),
    this.writer = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.imdbId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTitlesCompanion.insert({
    required String id,
    this.legacyId = const Value.absent(),
    required String mediaType,
    required String title,
    this.originalTitle = const Value.absent(),
    required String normalizedTitle,
    this.plot = const Value.absent(),
    this.year = const Value.absent(),
    this.rating = const Value.absent(),
    this.duration = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.isFeatured = const Value.absent(),
    this.castMembers = const Value.absent(),
    this.director = const Value.absent(),
    this.writer = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.imdbId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mediaType = Value(mediaType),
       title = Value(title),
       normalizedTitle = Value(normalizedTitle),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalTitle> custom({
    Expression<String>? id,
    Expression<String>? legacyId,
    Expression<String>? mediaType,
    Expression<String>? title,
    Expression<String>? originalTitle,
    Expression<String>? normalizedTitle,
    Expression<String>? plot,
    Expression<int>? year,
    Expression<double>? rating,
    Expression<String>? duration,
    Expression<String>? posterUrl,
    Expression<String>? backdropUrl,
    Expression<bool>? isFeatured,
    Expression<String>? castMembers,
    Expression<String>? director,
    Expression<String>? writer,
    Expression<String>? countryCode,
    Expression<int>? tmdbId,
    Expression<String>? imdbId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (legacyId != null) 'legacy_id': legacyId,
      if (mediaType != null) 'media_type': mediaType,
      if (title != null) 'title': title,
      if (originalTitle != null) 'original_title': originalTitle,
      if (normalizedTitle != null) 'normalized_title': normalizedTitle,
      if (plot != null) 'plot': plot,
      if (year != null) 'year': year,
      if (rating != null) 'rating': rating,
      if (duration != null) 'duration': duration,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (isFeatured != null) 'is_featured': isFeatured,
      if (castMembers != null) 'cast_members': castMembers,
      if (director != null) 'director': director,
      if (writer != null) 'writer': writer,
      if (countryCode != null) 'country_code': countryCode,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (imdbId != null) 'imdb_id': imdbId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTitlesCompanion copyWith({
    Value<String>? id,
    Value<String?>? legacyId,
    Value<String>? mediaType,
    Value<String>? title,
    Value<String?>? originalTitle,
    Value<String>? normalizedTitle,
    Value<String?>? plot,
    Value<int?>? year,
    Value<double?>? rating,
    Value<String?>? duration,
    Value<String?>? posterUrl,
    Value<String?>? backdropUrl,
    Value<bool>? isFeatured,
    Value<String?>? castMembers,
    Value<String?>? director,
    Value<String?>? writer,
    Value<String?>? countryCode,
    Value<int?>? tmdbId,
    Value<String?>? imdbId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return LocalTitlesCompanion(
      id: id ?? this.id,
      legacyId: legacyId ?? this.legacyId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      plot: plot ?? this.plot,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      duration: duration ?? this.duration,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      isFeatured: isFeatured ?? this.isFeatured,
      castMembers: castMembers ?? this.castMembers,
      director: director ?? this.director,
      writer: writer ?? this.writer,
      countryCode: countryCode ?? this.countryCode,
      tmdbId: tmdbId ?? this.tmdbId,
      imdbId: imdbId ?? this.imdbId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (legacyId.present) {
      map['legacy_id'] = Variable<String>(legacyId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (originalTitle.present) {
      map['original_title'] = Variable<String>(originalTitle.value);
    }
    if (normalizedTitle.present) {
      map['normalized_title'] = Variable<String>(normalizedTitle.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (duration.present) {
      map['duration'] = Variable<String>(duration.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (isFeatured.present) {
      map['is_featured'] = Variable<bool>(isFeatured.value);
    }
    if (castMembers.present) {
      map['cast_members'] = Variable<String>(castMembers.value);
    }
    if (director.present) {
      map['director'] = Variable<String>(director.value);
    }
    if (writer.present) {
      map['writer'] = Variable<String>(writer.value);
    }
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (imdbId.present) {
      map['imdb_id'] = Variable<String>(imdbId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTitlesCompanion(')
          ..write('id: $id, ')
          ..write('legacyId: $legacyId, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('originalTitle: $originalTitle, ')
          ..write('normalizedTitle: $normalizedTitle, ')
          ..write('plot: $plot, ')
          ..write('year: $year, ')
          ..write('rating: $rating, ')
          ..write('duration: $duration, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('isFeatured: $isFeatured, ')
          ..write('castMembers: $castMembers, ')
          ..write('director: $director, ')
          ..write('writer: $writer, ')
          ..write('countryCode: $countryCode, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('imdbId: $imdbId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalGenresTable extends LocalGenres
    with TableInfo<$LocalGenresTable, LocalGenre> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalGenresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, slug];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_genres';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalGenre> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalGenre map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalGenre(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
    );
  }

  @override
  $LocalGenresTable createAlias(String alias) {
    return $LocalGenresTable(attachedDatabase, alias);
  }
}

class LocalGenre extends DataClass implements Insertable<LocalGenre> {
  final String id;
  final String name;
  final String slug;
  const LocalGenre({required this.id, required this.name, required this.slug});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['slug'] = Variable<String>(slug);
    return map;
  }

  LocalGenresCompanion toCompanion(bool nullToAbsent) {
    return LocalGenresCompanion(
      id: Value(id),
      name: Value(name),
      slug: Value(slug),
    );
  }

  factory LocalGenre.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalGenre(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      slug: serializer.fromJson<String>(json['slug']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'slug': serializer.toJson<String>(slug),
    };
  }

  LocalGenre copyWith({String? id, String? name, String? slug}) => LocalGenre(
    id: id ?? this.id,
    name: name ?? this.name,
    slug: slug ?? this.slug,
  );
  LocalGenre copyWithCompanion(LocalGenresCompanion data) {
    return LocalGenre(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      slug: data.slug.present ? data.slug.value : this.slug,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalGenre(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('slug: $slug')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, slug);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalGenre &&
          other.id == this.id &&
          other.name == this.name &&
          other.slug == this.slug);
}

class LocalGenresCompanion extends UpdateCompanion<LocalGenre> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> slug;
  final Value<int> rowid;
  const LocalGenresCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.slug = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalGenresCompanion.insert({
    required String id,
    required String name,
    required String slug,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       slug = Value(slug);
  static Insertable<LocalGenre> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? slug,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (slug != null) 'slug': slug,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalGenresCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? slug,
    Value<int>? rowid,
  }) {
    return LocalGenresCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalGenresCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('slug: $slug, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalLanguagesTable extends LocalLanguages
    with TableInfo<$LocalLanguagesTable, LocalLanguage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLanguagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, code, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_languages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalLanguage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalLanguage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalLanguage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $LocalLanguagesTable createAlias(String alias) {
    return $LocalLanguagesTable(attachedDatabase, alias);
  }
}

class LocalLanguage extends DataClass implements Insertable<LocalLanguage> {
  final String id;
  final String code;
  final String name;
  const LocalLanguage({
    required this.id,
    required this.code,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    return map;
  }

  LocalLanguagesCompanion toCompanion(bool nullToAbsent) {
    return LocalLanguagesCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
    );
  }

  factory LocalLanguage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalLanguage(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
    };
  }

  LocalLanguage copyWith({String? id, String? code, String? name}) =>
      LocalLanguage(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
      );
  LocalLanguage copyWithCompanion(LocalLanguagesCompanion data) {
    return LocalLanguage(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalLanguage(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalLanguage &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name);
}

class LocalLanguagesCompanion extends UpdateCompanion<LocalLanguage> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<int> rowid;
  const LocalLanguagesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalLanguagesCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name);
  static Insertable<LocalLanguage> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalLanguagesCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return LocalLanguagesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLanguagesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTitleGenresTable extends LocalTitleGenres
    with TableInfo<$LocalTitleGenresTable, LocalTitleGenre> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTitleGenresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_titles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _genreIdMeta = const VerificationMeta(
    'genreId',
  );
  @override
  late final GeneratedColumn<String> genreId = GeneratedColumn<String>(
    'genre_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_genres (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [titleId, genreId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_title_genres';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTitleGenre> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('genre_id')) {
      context.handle(
        _genreIdMeta,
        genreId.isAcceptableOrUnknown(data['genre_id']!, _genreIdMeta),
      );
    } else if (isInserting) {
      context.missing(_genreIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId, genreId};
  @override
  LocalTitleGenre map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTitleGenre(
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      genreId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre_id'],
      )!,
    );
  }

  @override
  $LocalTitleGenresTable createAlias(String alias) {
    return $LocalTitleGenresTable(attachedDatabase, alias);
  }
}

class LocalTitleGenre extends DataClass implements Insertable<LocalTitleGenre> {
  final String titleId;
  final String genreId;
  const LocalTitleGenre({required this.titleId, required this.genreId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_id'] = Variable<String>(titleId);
    map['genre_id'] = Variable<String>(genreId);
    return map;
  }

  LocalTitleGenresCompanion toCompanion(bool nullToAbsent) {
    return LocalTitleGenresCompanion(
      titleId: Value(titleId),
      genreId: Value(genreId),
    );
  }

  factory LocalTitleGenre.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTitleGenre(
      titleId: serializer.fromJson<String>(json['titleId']),
      genreId: serializer.fromJson<String>(json['genreId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'titleId': serializer.toJson<String>(titleId),
      'genreId': serializer.toJson<String>(genreId),
    };
  }

  LocalTitleGenre copyWith({String? titleId, String? genreId}) =>
      LocalTitleGenre(
        titleId: titleId ?? this.titleId,
        genreId: genreId ?? this.genreId,
      );
  LocalTitleGenre copyWithCompanion(LocalTitleGenresCompanion data) {
    return LocalTitleGenre(
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      genreId: data.genreId.present ? data.genreId.value : this.genreId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTitleGenre(')
          ..write('titleId: $titleId, ')
          ..write('genreId: $genreId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(titleId, genreId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTitleGenre &&
          other.titleId == this.titleId &&
          other.genreId == this.genreId);
}

class LocalTitleGenresCompanion extends UpdateCompanion<LocalTitleGenre> {
  final Value<String> titleId;
  final Value<String> genreId;
  final Value<int> rowid;
  const LocalTitleGenresCompanion({
    this.titleId = const Value.absent(),
    this.genreId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTitleGenresCompanion.insert({
    required String titleId,
    required String genreId,
    this.rowid = const Value.absent(),
  }) : titleId = Value(titleId),
       genreId = Value(genreId);
  static Insertable<LocalTitleGenre> custom({
    Expression<String>? titleId,
    Expression<String>? genreId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleId != null) 'title_id': titleId,
      if (genreId != null) 'genre_id': genreId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTitleGenresCompanion copyWith({
    Value<String>? titleId,
    Value<String>? genreId,
    Value<int>? rowid,
  }) {
    return LocalTitleGenresCompanion(
      titleId: titleId ?? this.titleId,
      genreId: genreId ?? this.genreId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (genreId.present) {
      map['genre_id'] = Variable<String>(genreId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTitleGenresCompanion(')
          ..write('titleId: $titleId, ')
          ..write('genreId: $genreId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSeasonsTable extends LocalSeasons
    with TableInfo<$LocalSeasonsTable, LocalSeason> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSeasonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_titles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seasonNumberMeta = const VerificationMeta(
    'seasonNumber',
  );
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
    'season_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterUrlMeta = const VerificationMeta(
    'posterUrl',
  );
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
    'poster_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titleId,
    seasonNumber,
    name,
    plot,
    posterUrl,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_seasons';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSeason> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('season_number')) {
      context.handle(
        _seasonNumberMeta,
        seasonNumber.isAcceptableOrUnknown(
          data['season_number']!,
          _seasonNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seasonNumberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('poster_url')) {
      context.handle(
        _posterUrlMeta,
        posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSeason map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSeason(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      seasonNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season_number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      posterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_url'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $LocalSeasonsTable createAlias(String alias) {
    return $LocalSeasonsTable(attachedDatabase, alias);
  }
}

class LocalSeason extends DataClass implements Insertable<LocalSeason> {
  final String id;
  final String titleId;
  final int seasonNumber;
  final String? name;
  final String? plot;
  final String? posterUrl;
  final bool isDeleted;
  const LocalSeason({
    required this.id,
    required this.titleId,
    required this.seasonNumber,
    this.name,
    this.plot,
    this.posterUrl,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title_id'] = Variable<String>(titleId);
    map['season_number'] = Variable<int>(seasonNumber);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  LocalSeasonsCompanion toCompanion(bool nullToAbsent) {
    return LocalSeasonsCompanion(
      id: Value(id),
      titleId: Value(titleId),
      seasonNumber: Value(seasonNumber),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      isDeleted: Value(isDeleted),
    );
  }

  factory LocalSeason.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSeason(
      id: serializer.fromJson<String>(json['id']),
      titleId: serializer.fromJson<String>(json['titleId']),
      seasonNumber: serializer.fromJson<int>(json['seasonNumber']),
      name: serializer.fromJson<String?>(json['name']),
      plot: serializer.fromJson<String?>(json['plot']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'titleId': serializer.toJson<String>(titleId),
      'seasonNumber': serializer.toJson<int>(seasonNumber),
      'name': serializer.toJson<String?>(name),
      'plot': serializer.toJson<String?>(plot),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  LocalSeason copyWith({
    String? id,
    String? titleId,
    int? seasonNumber,
    Value<String?> name = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<String?> posterUrl = const Value.absent(),
    bool? isDeleted,
  }) => LocalSeason(
    id: id ?? this.id,
    titleId: titleId ?? this.titleId,
    seasonNumber: seasonNumber ?? this.seasonNumber,
    name: name.present ? name.value : this.name,
    plot: plot.present ? plot.value : this.plot,
    posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  LocalSeason copyWithCompanion(LocalSeasonsCompanion data) {
    return LocalSeason(
      id: data.id.present ? data.id.value : this.id,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      name: data.name.present ? data.name.value : this.name,
      plot: data.plot.present ? data.plot.value : this.plot,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSeason(')
          ..write('id: $id, ')
          ..write('titleId: $titleId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('name: $name, ')
          ..write('plot: $plot, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, titleId, seasonNumber, name, plot, posterUrl, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSeason &&
          other.id == this.id &&
          other.titleId == this.titleId &&
          other.seasonNumber == this.seasonNumber &&
          other.name == this.name &&
          other.plot == this.plot &&
          other.posterUrl == this.posterUrl &&
          other.isDeleted == this.isDeleted);
}

class LocalSeasonsCompanion extends UpdateCompanion<LocalSeason> {
  final Value<String> id;
  final Value<String> titleId;
  final Value<int> seasonNumber;
  final Value<String?> name;
  final Value<String?> plot;
  final Value<String?> posterUrl;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const LocalSeasonsCompanion({
    this.id = const Value.absent(),
    this.titleId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.name = const Value.absent(),
    this.plot = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSeasonsCompanion.insert({
    required String id,
    required String titleId,
    required int seasonNumber,
    this.name = const Value.absent(),
    this.plot = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       titleId = Value(titleId),
       seasonNumber = Value(seasonNumber);
  static Insertable<LocalSeason> custom({
    Expression<String>? id,
    Expression<String>? titleId,
    Expression<int>? seasonNumber,
    Expression<String>? name,
    Expression<String>? plot,
    Expression<String>? posterUrl,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titleId != null) 'title_id': titleId,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (name != null) 'name': name,
      if (plot != null) 'plot': plot,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSeasonsCompanion copyWith({
    Value<String>? id,
    Value<String>? titleId,
    Value<int>? seasonNumber,
    Value<String?>? name,
    Value<String?>? plot,
    Value<String?>? posterUrl,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return LocalSeasonsCompanion(
      id: id ?? this.id,
      titleId: titleId ?? this.titleId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      name: name ?? this.name,
      plot: plot ?? this.plot,
      posterUrl: posterUrl ?? this.posterUrl,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSeasonsCompanion(')
          ..write('id: $id, ')
          ..write('titleId: $titleId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('name: $name, ')
          ..write('plot: $plot, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEpisodesTable extends LocalEpisodes
    with TableInfo<$LocalEpisodesTable, LocalEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonIdMeta = const VerificationMeta(
    'seasonId',
  );
  @override
  late final GeneratedColumn<String> seasonId = GeneratedColumn<String>(
    'season_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_seasons (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<String> duration = GeneratedColumn<String>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stillUrlMeta = const VerificationMeta(
    'stillUrl',
  );
  @override
  late final GeneratedColumn<String> stillUrl = GeneratedColumn<String>(
    'still_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    seasonId,
    episodeNumber,
    title,
    plot,
    duration,
    stillUrl,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('season_id')) {
      context.handle(
        _seasonIdMeta,
        seasonId.isAcceptableOrUnknown(data['season_id']!, _seasonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seasonIdMeta);
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeNumberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('still_url')) {
      context.handle(
        _stillUrlMeta,
        stillUrl.isAcceptableOrUnknown(data['still_url']!, _stillUrlMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEpisode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      seasonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season_id'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duration'],
      ),
      stillUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}still_url'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $LocalEpisodesTable createAlias(String alias) {
    return $LocalEpisodesTable(attachedDatabase, alias);
  }
}

class LocalEpisode extends DataClass implements Insertable<LocalEpisode> {
  final String id;
  final String seasonId;
  final int episodeNumber;
  final String title;
  final String? plot;
  final String? duration;
  final String? stillUrl;
  final bool isDeleted;
  const LocalEpisode({
    required this.id,
    required this.seasonId,
    required this.episodeNumber,
    required this.title,
    this.plot,
    this.duration,
    this.stillUrl,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['season_id'] = Variable<String>(seasonId);
    map['episode_number'] = Variable<int>(episodeNumber);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<String>(duration);
    }
    if (!nullToAbsent || stillUrl != null) {
      map['still_url'] = Variable<String>(stillUrl);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  LocalEpisodesCompanion toCompanion(bool nullToAbsent) {
    return LocalEpisodesCompanion(
      id: Value(id),
      seasonId: Value(seasonId),
      episodeNumber: Value(episodeNumber),
      title: Value(title),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      stillUrl: stillUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(stillUrl),
      isDeleted: Value(isDeleted),
    );
  }

  factory LocalEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEpisode(
      id: serializer.fromJson<String>(json['id']),
      seasonId: serializer.fromJson<String>(json['seasonId']),
      episodeNumber: serializer.fromJson<int>(json['episodeNumber']),
      title: serializer.fromJson<String>(json['title']),
      plot: serializer.fromJson<String?>(json['plot']),
      duration: serializer.fromJson<String?>(json['duration']),
      stillUrl: serializer.fromJson<String?>(json['stillUrl']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'seasonId': serializer.toJson<String>(seasonId),
      'episodeNumber': serializer.toJson<int>(episodeNumber),
      'title': serializer.toJson<String>(title),
      'plot': serializer.toJson<String?>(plot),
      'duration': serializer.toJson<String?>(duration),
      'stillUrl': serializer.toJson<String?>(stillUrl),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  LocalEpisode copyWith({
    String? id,
    String? seasonId,
    int? episodeNumber,
    String? title,
    Value<String?> plot = const Value.absent(),
    Value<String?> duration = const Value.absent(),
    Value<String?> stillUrl = const Value.absent(),
    bool? isDeleted,
  }) => LocalEpisode(
    id: id ?? this.id,
    seasonId: seasonId ?? this.seasonId,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    title: title ?? this.title,
    plot: plot.present ? plot.value : this.plot,
    duration: duration.present ? duration.value : this.duration,
    stillUrl: stillUrl.present ? stillUrl.value : this.stillUrl,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  LocalEpisode copyWithCompanion(LocalEpisodesCompanion data) {
    return LocalEpisode(
      id: data.id.present ? data.id.value : this.id,
      seasonId: data.seasonId.present ? data.seasonId.value : this.seasonId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      title: data.title.present ? data.title.value : this.title,
      plot: data.plot.present ? data.plot.value : this.plot,
      duration: data.duration.present ? data.duration.value : this.duration,
      stillUrl: data.stillUrl.present ? data.stillUrl.value : this.stillUrl,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEpisode(')
          ..write('id: $id, ')
          ..write('seasonId: $seasonId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('plot: $plot, ')
          ..write('duration: $duration, ')
          ..write('stillUrl: $stillUrl, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    seasonId,
    episodeNumber,
    title,
    plot,
    duration,
    stillUrl,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEpisode &&
          other.id == this.id &&
          other.seasonId == this.seasonId &&
          other.episodeNumber == this.episodeNumber &&
          other.title == this.title &&
          other.plot == this.plot &&
          other.duration == this.duration &&
          other.stillUrl == this.stillUrl &&
          other.isDeleted == this.isDeleted);
}

class LocalEpisodesCompanion extends UpdateCompanion<LocalEpisode> {
  final Value<String> id;
  final Value<String> seasonId;
  final Value<int> episodeNumber;
  final Value<String> title;
  final Value<String?> plot;
  final Value<String?> duration;
  final Value<String?> stillUrl;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const LocalEpisodesCompanion({
    this.id = const Value.absent(),
    this.seasonId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.plot = const Value.absent(),
    this.duration = const Value.absent(),
    this.stillUrl = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEpisodesCompanion.insert({
    required String id,
    required String seasonId,
    required int episodeNumber,
    required String title,
    this.plot = const Value.absent(),
    this.duration = const Value.absent(),
    this.stillUrl = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       seasonId = Value(seasonId),
       episodeNumber = Value(episodeNumber),
       title = Value(title);
  static Insertable<LocalEpisode> custom({
    Expression<String>? id,
    Expression<String>? seasonId,
    Expression<int>? episodeNumber,
    Expression<String>? title,
    Expression<String>? plot,
    Expression<String>? duration,
    Expression<String>? stillUrl,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seasonId != null) 'season_id': seasonId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (title != null) 'title': title,
      if (plot != null) 'plot': plot,
      if (duration != null) 'duration': duration,
      if (stillUrl != null) 'still_url': stillUrl,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEpisodesCompanion copyWith({
    Value<String>? id,
    Value<String>? seasonId,
    Value<int>? episodeNumber,
    Value<String>? title,
    Value<String?>? plot,
    Value<String?>? duration,
    Value<String?>? stillUrl,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return LocalEpisodesCompanion(
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      plot: plot ?? this.plot,
      duration: duration ?? this.duration,
      stillUrl: stillUrl ?? this.stillUrl,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (seasonId.present) {
      map['season_id'] = Variable<String>(seasonId.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (duration.present) {
      map['duration'] = Variable<String>(duration.value);
    }
    if (stillUrl.present) {
      map['still_url'] = Variable<String>(stillUrl.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEpisodesCompanion(')
          ..write('id: $id, ')
          ..write('seasonId: $seasonId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('plot: $plot, ')
          ..write('duration: $duration, ')
          ..write('stillUrl: $stillUrl, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSourcesTable extends LocalSources
    with TableInfo<$LocalSourcesTable, LocalSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_titles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<String> episodeId = GeneratedColumn<String>(
    'episode_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_episodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _requiresWebviewMeta = const VerificationMeta(
    'requiresWebview',
  );
  @override
  late final GeneratedColumn<bool> requiresWebview = GeneratedColumn<bool>(
    'requires_webview',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_webview" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _refererUrlMeta = const VerificationMeta(
    'refererUrl',
  );
  @override
  late final GeneratedColumn<String> refererUrl = GeneratedColumn<String>(
    'referer_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originUrlMeta = const VerificationMeta(
    'originUrl',
  );
  @override
  late final GeneratedColumn<String> originUrl = GeneratedColumn<String>(
    'origin_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userAgentProfileMeta = const VerificationMeta(
    'userAgentProfile',
  );
  @override
  late final GeneratedColumn<String> userAgentProfile = GeneratedColumn<String>(
    'user_agent_profile',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titleId,
    episodeId,
    name,
    url,
    language,
    orderIndex,
    status,
    requiresWebview,
    refererUrl,
    originUrl,
    userAgentProfile,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('requires_webview')) {
      context.handle(
        _requiresWebviewMeta,
        requiresWebview.isAcceptableOrUnknown(
          data['requires_webview']!,
          _requiresWebviewMeta,
        ),
      );
    }
    if (data.containsKey('referer_url')) {
      context.handle(
        _refererUrlMeta,
        refererUrl.isAcceptableOrUnknown(data['referer_url']!, _refererUrlMeta),
      );
    }
    if (data.containsKey('origin_url')) {
      context.handle(
        _originUrlMeta,
        originUrl.isAcceptableOrUnknown(data['origin_url']!, _originUrlMeta),
      );
    }
    if (data.containsKey('user_agent_profile')) {
      context.handle(
        _userAgentProfileMeta,
        userAgentProfile.isAcceptableOrUnknown(
          data['user_agent_profile']!,
          _userAgentProfileMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      ),
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      requiresWebview: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_webview'],
      )!,
      refererUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}referer_url'],
      ),
      originUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_url'],
      ),
      userAgentProfile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_agent_profile'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $LocalSourcesTable createAlias(String alias) {
    return $LocalSourcesTable(attachedDatabase, alias);
  }
}

class LocalSource extends DataClass implements Insertable<LocalSource> {
  final String id;
  final String? titleId;
  final String? episodeId;
  final String name;
  final String url;
  final String? language;
  final int orderIndex;
  final String status;
  final bool requiresWebview;
  final String? refererUrl;
  final String? originUrl;
  final String? userAgentProfile;
  final bool isDeleted;
  const LocalSource({
    required this.id,
    this.titleId,
    this.episodeId,
    required this.name,
    required this.url,
    this.language,
    required this.orderIndex,
    required this.status,
    required this.requiresWebview,
    this.refererUrl,
    this.originUrl,
    this.userAgentProfile,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || titleId != null) {
      map['title_id'] = Variable<String>(titleId);
    }
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<String>(episodeId);
    }
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['status'] = Variable<String>(status);
    map['requires_webview'] = Variable<bool>(requiresWebview);
    if (!nullToAbsent || refererUrl != null) {
      map['referer_url'] = Variable<String>(refererUrl);
    }
    if (!nullToAbsent || originUrl != null) {
      map['origin_url'] = Variable<String>(originUrl);
    }
    if (!nullToAbsent || userAgentProfile != null) {
      map['user_agent_profile'] = Variable<String>(userAgentProfile);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  LocalSourcesCompanion toCompanion(bool nullToAbsent) {
    return LocalSourcesCompanion(
      id: Value(id),
      titleId: titleId == null && nullToAbsent
          ? const Value.absent()
          : Value(titleId),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      name: Value(name),
      url: Value(url),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      orderIndex: Value(orderIndex),
      status: Value(status),
      requiresWebview: Value(requiresWebview),
      refererUrl: refererUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(refererUrl),
      originUrl: originUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(originUrl),
      userAgentProfile: userAgentProfile == null && nullToAbsent
          ? const Value.absent()
          : Value(userAgentProfile),
      isDeleted: Value(isDeleted),
    );
  }

  factory LocalSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSource(
      id: serializer.fromJson<String>(json['id']),
      titleId: serializer.fromJson<String?>(json['titleId']),
      episodeId: serializer.fromJson<String?>(json['episodeId']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      language: serializer.fromJson<String?>(json['language']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      status: serializer.fromJson<String>(json['status']),
      requiresWebview: serializer.fromJson<bool>(json['requiresWebview']),
      refererUrl: serializer.fromJson<String?>(json['refererUrl']),
      originUrl: serializer.fromJson<String?>(json['originUrl']),
      userAgentProfile: serializer.fromJson<String?>(json['userAgentProfile']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'titleId': serializer.toJson<String?>(titleId),
      'episodeId': serializer.toJson<String?>(episodeId),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'language': serializer.toJson<String?>(language),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'status': serializer.toJson<String>(status),
      'requiresWebview': serializer.toJson<bool>(requiresWebview),
      'refererUrl': serializer.toJson<String?>(refererUrl),
      'originUrl': serializer.toJson<String?>(originUrl),
      'userAgentProfile': serializer.toJson<String?>(userAgentProfile),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  LocalSource copyWith({
    String? id,
    Value<String?> titleId = const Value.absent(),
    Value<String?> episodeId = const Value.absent(),
    String? name,
    String? url,
    Value<String?> language = const Value.absent(),
    int? orderIndex,
    String? status,
    bool? requiresWebview,
    Value<String?> refererUrl = const Value.absent(),
    Value<String?> originUrl = const Value.absent(),
    Value<String?> userAgentProfile = const Value.absent(),
    bool? isDeleted,
  }) => LocalSource(
    id: id ?? this.id,
    titleId: titleId.present ? titleId.value : this.titleId,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    name: name ?? this.name,
    url: url ?? this.url,
    language: language.present ? language.value : this.language,
    orderIndex: orderIndex ?? this.orderIndex,
    status: status ?? this.status,
    requiresWebview: requiresWebview ?? this.requiresWebview,
    refererUrl: refererUrl.present ? refererUrl.value : this.refererUrl,
    originUrl: originUrl.present ? originUrl.value : this.originUrl,
    userAgentProfile: userAgentProfile.present
        ? userAgentProfile.value
        : this.userAgentProfile,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  LocalSource copyWithCompanion(LocalSourcesCompanion data) {
    return LocalSource(
      id: data.id.present ? data.id.value : this.id,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      language: data.language.present ? data.language.value : this.language,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      status: data.status.present ? data.status.value : this.status,
      requiresWebview: data.requiresWebview.present
          ? data.requiresWebview.value
          : this.requiresWebview,
      refererUrl: data.refererUrl.present
          ? data.refererUrl.value
          : this.refererUrl,
      originUrl: data.originUrl.present ? data.originUrl.value : this.originUrl,
      userAgentProfile: data.userAgentProfile.present
          ? data.userAgentProfile.value
          : this.userAgentProfile,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSource(')
          ..write('id: $id, ')
          ..write('titleId: $titleId, ')
          ..write('episodeId: $episodeId, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('language: $language, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('status: $status, ')
          ..write('requiresWebview: $requiresWebview, ')
          ..write('refererUrl: $refererUrl, ')
          ..write('originUrl: $originUrl, ')
          ..write('userAgentProfile: $userAgentProfile, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    titleId,
    episodeId,
    name,
    url,
    language,
    orderIndex,
    status,
    requiresWebview,
    refererUrl,
    originUrl,
    userAgentProfile,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSource &&
          other.id == this.id &&
          other.titleId == this.titleId &&
          other.episodeId == this.episodeId &&
          other.name == this.name &&
          other.url == this.url &&
          other.language == this.language &&
          other.orderIndex == this.orderIndex &&
          other.status == this.status &&
          other.requiresWebview == this.requiresWebview &&
          other.refererUrl == this.refererUrl &&
          other.originUrl == this.originUrl &&
          other.userAgentProfile == this.userAgentProfile &&
          other.isDeleted == this.isDeleted);
}

class LocalSourcesCompanion extends UpdateCompanion<LocalSource> {
  final Value<String> id;
  final Value<String?> titleId;
  final Value<String?> episodeId;
  final Value<String> name;
  final Value<String> url;
  final Value<String?> language;
  final Value<int> orderIndex;
  final Value<String> status;
  final Value<bool> requiresWebview;
  final Value<String?> refererUrl;
  final Value<String?> originUrl;
  final Value<String?> userAgentProfile;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const LocalSourcesCompanion({
    this.id = const Value.absent(),
    this.titleId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.language = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.status = const Value.absent(),
    this.requiresWebview = const Value.absent(),
    this.refererUrl = const Value.absent(),
    this.originUrl = const Value.absent(),
    this.userAgentProfile = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSourcesCompanion.insert({
    required String id,
    this.titleId = const Value.absent(),
    this.episodeId = const Value.absent(),
    required String name,
    required String url,
    this.language = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.status = const Value.absent(),
    this.requiresWebview = const Value.absent(),
    this.refererUrl = const Value.absent(),
    this.originUrl = const Value.absent(),
    this.userAgentProfile = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       url = Value(url);
  static Insertable<LocalSource> custom({
    Expression<String>? id,
    Expression<String>? titleId,
    Expression<String>? episodeId,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? language,
    Expression<int>? orderIndex,
    Expression<String>? status,
    Expression<bool>? requiresWebview,
    Expression<String>? refererUrl,
    Expression<String>? originUrl,
    Expression<String>? userAgentProfile,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titleId != null) 'title_id': titleId,
      if (episodeId != null) 'episode_id': episodeId,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (language != null) 'language': language,
      if (orderIndex != null) 'order_index': orderIndex,
      if (status != null) 'status': status,
      if (requiresWebview != null) 'requires_webview': requiresWebview,
      if (refererUrl != null) 'referer_url': refererUrl,
      if (originUrl != null) 'origin_url': originUrl,
      if (userAgentProfile != null) 'user_agent_profile': userAgentProfile,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSourcesCompanion copyWith({
    Value<String>? id,
    Value<String?>? titleId,
    Value<String?>? episodeId,
    Value<String>? name,
    Value<String>? url,
    Value<String?>? language,
    Value<int>? orderIndex,
    Value<String>? status,
    Value<bool>? requiresWebview,
    Value<String?>? refererUrl,
    Value<String?>? originUrl,
    Value<String?>? userAgentProfile,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return LocalSourcesCompanion(
      id: id ?? this.id,
      titleId: titleId ?? this.titleId,
      episodeId: episodeId ?? this.episodeId,
      name: name ?? this.name,
      url: url ?? this.url,
      language: language ?? this.language,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
      requiresWebview: requiresWebview ?? this.requiresWebview,
      refererUrl: refererUrl ?? this.refererUrl,
      originUrl: originUrl ?? this.originUrl,
      userAgentProfile: userAgentProfile ?? this.userAgentProfile,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (requiresWebview.present) {
      map['requires_webview'] = Variable<bool>(requiresWebview.value);
    }
    if (refererUrl.present) {
      map['referer_url'] = Variable<String>(refererUrl.value);
    }
    if (originUrl.present) {
      map['origin_url'] = Variable<String>(originUrl.value);
    }
    if (userAgentProfile.present) {
      map['user_agent_profile'] = Variable<String>(userAgentProfile.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSourcesCompanion(')
          ..write('id: $id, ')
          ..write('titleId: $titleId, ')
          ..write('episodeId: $episodeId, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('language: $language, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('status: $status, ')
          ..write('requiresWebview: $requiresWebview, ')
          ..write('refererUrl: $refererUrl, ')
          ..write('originUrl: $originUrl, ')
          ..write('userAgentProfile: $userAgentProfile, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogSyncStatesTable extends CatalogSyncStates
    with TableInfo<$CatalogSyncStatesTable, CatalogSyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogSyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncKeyMeta = const VerificationMeta(
    'syncKey',
  );
  @override
  late final GeneratedColumn<String> syncKey = GeneratedColumn<String>(
    'sync_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastCatalogRevisionMeta =
      const VerificationMeta('lastCatalogRevision');
  @override
  late final GeneratedColumn<int> lastCatalogRevision = GeneratedColumn<int>(
    'last_catalog_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncTimestampMeta = const VerificationMeta(
    'lastSyncTimestamp',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncTimestamp =
      GeneratedColumn<DateTime>(
        'last_sync_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _totalSyncedMeta = const VerificationMeta(
    'totalSynced',
  );
  @override
  late final GeneratedColumn<int> totalSynced = GeneratedColumn<int>(
    'total_synced',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    syncKey,
    lastCatalogRevision,
    lastSyncTimestamp,
    totalSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogSyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_key')) {
      context.handle(
        _syncKeyMeta,
        syncKey.isAcceptableOrUnknown(data['sync_key']!, _syncKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_syncKeyMeta);
    }
    if (data.containsKey('last_catalog_revision')) {
      context.handle(
        _lastCatalogRevisionMeta,
        lastCatalogRevision.isAcceptableOrUnknown(
          data['last_catalog_revision']!,
          _lastCatalogRevisionMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_timestamp')) {
      context.handle(
        _lastSyncTimestampMeta,
        lastSyncTimestamp.isAcceptableOrUnknown(
          data['last_sync_timestamp']!,
          _lastSyncTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncTimestampMeta);
    }
    if (data.containsKey('total_synced')) {
      context.handle(
        _totalSyncedMeta,
        totalSynced.isAcceptableOrUnknown(
          data['total_synced']!,
          _totalSyncedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncKey};
  @override
  CatalogSyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogSyncState(
      syncKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_key'],
      )!,
      lastCatalogRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_catalog_revision'],
      )!,
      lastSyncTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_timestamp'],
      )!,
      totalSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_synced'],
      )!,
    );
  }

  @override
  $CatalogSyncStatesTable createAlias(String alias) {
    return $CatalogSyncStatesTable(attachedDatabase, alias);
  }
}

class CatalogSyncState extends DataClass
    implements Insertable<CatalogSyncState> {
  final String syncKey;
  final int lastCatalogRevision;
  final DateTime lastSyncTimestamp;
  final int totalSynced;
  const CatalogSyncState({
    required this.syncKey,
    required this.lastCatalogRevision,
    required this.lastSyncTimestamp,
    required this.totalSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_key'] = Variable<String>(syncKey);
    map['last_catalog_revision'] = Variable<int>(lastCatalogRevision);
    map['last_sync_timestamp'] = Variable<DateTime>(lastSyncTimestamp);
    map['total_synced'] = Variable<int>(totalSynced);
    return map;
  }

  CatalogSyncStatesCompanion toCompanion(bool nullToAbsent) {
    return CatalogSyncStatesCompanion(
      syncKey: Value(syncKey),
      lastCatalogRevision: Value(lastCatalogRevision),
      lastSyncTimestamp: Value(lastSyncTimestamp),
      totalSynced: Value(totalSynced),
    );
  }

  factory CatalogSyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogSyncState(
      syncKey: serializer.fromJson<String>(json['syncKey']),
      lastCatalogRevision: serializer.fromJson<int>(
        json['lastCatalogRevision'],
      ),
      lastSyncTimestamp: serializer.fromJson<DateTime>(
        json['lastSyncTimestamp'],
      ),
      totalSynced: serializer.fromJson<int>(json['totalSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncKey': serializer.toJson<String>(syncKey),
      'lastCatalogRevision': serializer.toJson<int>(lastCatalogRevision),
      'lastSyncTimestamp': serializer.toJson<DateTime>(lastSyncTimestamp),
      'totalSynced': serializer.toJson<int>(totalSynced),
    };
  }

  CatalogSyncState copyWith({
    String? syncKey,
    int? lastCatalogRevision,
    DateTime? lastSyncTimestamp,
    int? totalSynced,
  }) => CatalogSyncState(
    syncKey: syncKey ?? this.syncKey,
    lastCatalogRevision: lastCatalogRevision ?? this.lastCatalogRevision,
    lastSyncTimestamp: lastSyncTimestamp ?? this.lastSyncTimestamp,
    totalSynced: totalSynced ?? this.totalSynced,
  );
  CatalogSyncState copyWithCompanion(CatalogSyncStatesCompanion data) {
    return CatalogSyncState(
      syncKey: data.syncKey.present ? data.syncKey.value : this.syncKey,
      lastCatalogRevision: data.lastCatalogRevision.present
          ? data.lastCatalogRevision.value
          : this.lastCatalogRevision,
      lastSyncTimestamp: data.lastSyncTimestamp.present
          ? data.lastSyncTimestamp.value
          : this.lastSyncTimestamp,
      totalSynced: data.totalSynced.present
          ? data.totalSynced.value
          : this.totalSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogSyncState(')
          ..write('syncKey: $syncKey, ')
          ..write('lastCatalogRevision: $lastCatalogRevision, ')
          ..write('lastSyncTimestamp: $lastSyncTimestamp, ')
          ..write('totalSynced: $totalSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(syncKey, lastCatalogRevision, lastSyncTimestamp, totalSynced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogSyncState &&
          other.syncKey == this.syncKey &&
          other.lastCatalogRevision == this.lastCatalogRevision &&
          other.lastSyncTimestamp == this.lastSyncTimestamp &&
          other.totalSynced == this.totalSynced);
}

class CatalogSyncStatesCompanion extends UpdateCompanion<CatalogSyncState> {
  final Value<String> syncKey;
  final Value<int> lastCatalogRevision;
  final Value<DateTime> lastSyncTimestamp;
  final Value<int> totalSynced;
  final Value<int> rowid;
  const CatalogSyncStatesCompanion({
    this.syncKey = const Value.absent(),
    this.lastCatalogRevision = const Value.absent(),
    this.lastSyncTimestamp = const Value.absent(),
    this.totalSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogSyncStatesCompanion.insert({
    required String syncKey,
    this.lastCatalogRevision = const Value.absent(),
    required DateTime lastSyncTimestamp,
    this.totalSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : syncKey = Value(syncKey),
       lastSyncTimestamp = Value(lastSyncTimestamp);
  static Insertable<CatalogSyncState> custom({
    Expression<String>? syncKey,
    Expression<int>? lastCatalogRevision,
    Expression<DateTime>? lastSyncTimestamp,
    Expression<int>? totalSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncKey != null) 'sync_key': syncKey,
      if (lastCatalogRevision != null)
        'last_catalog_revision': lastCatalogRevision,
      if (lastSyncTimestamp != null) 'last_sync_timestamp': lastSyncTimestamp,
      if (totalSynced != null) 'total_synced': totalSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogSyncStatesCompanion copyWith({
    Value<String>? syncKey,
    Value<int>? lastCatalogRevision,
    Value<DateTime>? lastSyncTimestamp,
    Value<int>? totalSynced,
    Value<int>? rowid,
  }) {
    return CatalogSyncStatesCompanion(
      syncKey: syncKey ?? this.syncKey,
      lastCatalogRevision: lastCatalogRevision ?? this.lastCatalogRevision,
      lastSyncTimestamp: lastSyncTimestamp ?? this.lastSyncTimestamp,
      totalSynced: totalSynced ?? this.totalSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncKey.present) {
      map['sync_key'] = Variable<String>(syncKey.value);
    }
    if (lastCatalogRevision.present) {
      map['last_catalog_revision'] = Variable<int>(lastCatalogRevision.value);
    }
    if (lastSyncTimestamp.present) {
      map['last_sync_timestamp'] = Variable<DateTime>(lastSyncTimestamp.value);
    }
    if (totalSynced.present) {
      map['total_synced'] = Variable<int>(totalSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogSyncStatesCompanion(')
          ..write('syncKey: $syncKey, ')
          ..write('lastCatalogRevision: $lastCatalogRevision, ')
          ..write('lastSyncTimestamp: $lastSyncTimestamp, ')
          ..write('totalSynced: $totalSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CatalogDatabase extends GeneratedDatabase {
  _$CatalogDatabase(QueryExecutor e) : super(e);
  $CatalogDatabaseManager get managers => $CatalogDatabaseManager(this);
  late final $LocalTitlesTable localTitles = $LocalTitlesTable(this);
  late final $LocalGenresTable localGenres = $LocalGenresTable(this);
  late final $LocalLanguagesTable localLanguages = $LocalLanguagesTable(this);
  late final $LocalTitleGenresTable localTitleGenres = $LocalTitleGenresTable(
    this,
  );
  late final $LocalSeasonsTable localSeasons = $LocalSeasonsTable(this);
  late final $LocalEpisodesTable localEpisodes = $LocalEpisodesTable(this);
  late final $LocalSourcesTable localSources = $LocalSourcesTable(this);
  late final $CatalogSyncStatesTable catalogSyncStates =
      $CatalogSyncStatesTable(this);
  late final CatalogDao catalogDao = CatalogDao(this as CatalogDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localTitles,
    localGenres,
    localLanguages,
    localTitleGenres,
    localSeasons,
    localEpisodes,
    localSources,
    catalogSyncStates,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_titles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_title_genres', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_genres',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_title_genres', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_titles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_seasons', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_seasons',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_episodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_titles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_sources', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_episodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_sources', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LocalTitlesTableCreateCompanionBuilder =
    LocalTitlesCompanion Function({
      required String id,
      Value<String?> legacyId,
      required String mediaType,
      required String title,
      Value<String?> originalTitle,
      required String normalizedTitle,
      Value<String?> plot,
      Value<int?> year,
      Value<double?> rating,
      Value<String?> duration,
      Value<String?> posterUrl,
      Value<String?> backdropUrl,
      Value<bool> isFeatured,
      Value<String?> castMembers,
      Value<String?> director,
      Value<String?> writer,
      Value<String?> countryCode,
      Value<int?> tmdbId,
      Value<String?> imdbId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$LocalTitlesTableUpdateCompanionBuilder =
    LocalTitlesCompanion Function({
      Value<String> id,
      Value<String?> legacyId,
      Value<String> mediaType,
      Value<String> title,
      Value<String?> originalTitle,
      Value<String> normalizedTitle,
      Value<String?> plot,
      Value<int?> year,
      Value<double?> rating,
      Value<String?> duration,
      Value<String?> posterUrl,
      Value<String?> backdropUrl,
      Value<bool> isFeatured,
      Value<String?> castMembers,
      Value<String?> director,
      Value<String?> writer,
      Value<String?> countryCode,
      Value<int?> tmdbId,
      Value<String?> imdbId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$LocalTitlesTableReferences
    extends BaseReferences<_$CatalogDatabase, $LocalTitlesTable, LocalTitle> {
  $$LocalTitlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalTitleGenresTable, List<LocalTitleGenre>>
  _localTitleGenresRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localTitleGenres,
        aliasName: 'local_titles__id__local_title_genres__title_id',
      );

  $$LocalTitleGenresTableProcessedTableManager get localTitleGenresRefs {
    final manager = $$LocalTitleGenresTableTableManager(
      $_db,
      $_db.localTitleGenres,
    ).filter((f) => f.titleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localTitleGenresRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalSeasonsTable, List<LocalSeason>>
  _localSeasonsRefsTable(_$CatalogDatabase db) => MultiTypedResultKey.fromTable(
    db.localSeasons,
    aliasName: 'local_titles__id__local_seasons__title_id',
  );

  $$LocalSeasonsTableProcessedTableManager get localSeasonsRefs {
    final manager = $$LocalSeasonsTableTableManager(
      $_db,
      $_db.localSeasons,
    ).filter((f) => f.titleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localSeasonsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalSourcesTable, List<LocalSource>>
  _localSourcesRefsTable(_$CatalogDatabase db) => MultiTypedResultKey.fromTable(
    db.localSources,
    aliasName: 'local_titles__id__local_sources__title_id',
  );

  $$LocalSourcesTableProcessedTableManager get localSourcesRefs {
    final manager = $$LocalSourcesTableTableManager(
      $_db,
      $_db.localSources,
    ).filter((f) => f.titleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localSourcesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalTitlesTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalTitlesTable> {
  $$LocalTitlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFeatured => $composableBuilder(
    column: $table.isFeatured,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get castMembers => $composableBuilder(
    column: $table.castMembers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get writer => $composableBuilder(
    column: $table.writer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imdbId => $composableBuilder(
    column: $table.imdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localTitleGenresRefs(
    Expression<bool> Function($$LocalTitleGenresTableFilterComposer f) f,
  ) {
    final $$LocalTitleGenresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localTitleGenres,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitleGenresTableFilterComposer(
            $db: $db,
            $table: $db.localTitleGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localSeasonsRefs(
    Expression<bool> Function($$LocalSeasonsTableFilterComposer f) f,
  ) {
    final $$LocalSeasonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSeasons,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSeasonsTableFilterComposer(
            $db: $db,
            $table: $db.localSeasons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localSourcesRefs(
    Expression<bool> Function($$LocalSourcesTableFilterComposer f) f,
  ) {
    final $$LocalSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSources,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSourcesTableFilterComposer(
            $db: $db,
            $table: $db.localSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalTitlesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalTitlesTable> {
  $$LocalTitlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFeatured => $composableBuilder(
    column: $table.isFeatured,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get castMembers => $composableBuilder(
    column: $table.castMembers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get writer => $composableBuilder(
    column: $table.writer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imdbId => $composableBuilder(
    column: $table.imdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTitlesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalTitlesTable> {
  $$LocalTitlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get originalTitle => $composableBuilder(
    column: $table.originalTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get normalizedTitle => $composableBuilder(
    column: $table.normalizedTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFeatured => $composableBuilder(
    column: $table.isFeatured,
    builder: (column) => column,
  );

  GeneratedColumn<String> get castMembers => $composableBuilder(
    column: $table.castMembers,
    builder: (column) => column,
  );

  GeneratedColumn<String> get director =>
      $composableBuilder(column: $table.director, builder: (column) => column);

  GeneratedColumn<String> get writer =>
      $composableBuilder(column: $table.writer, builder: (column) => column);

  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<String> get imdbId =>
      $composableBuilder(column: $table.imdbId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  Expression<T> localTitleGenresRefs<T extends Object>(
    Expression<T> Function($$LocalTitleGenresTableAnnotationComposer a) f,
  ) {
    final $$LocalTitleGenresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localTitleGenres,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitleGenresTableAnnotationComposer(
            $db: $db,
            $table: $db.localTitleGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> localSeasonsRefs<T extends Object>(
    Expression<T> Function($$LocalSeasonsTableAnnotationComposer a) f,
  ) {
    final $$LocalSeasonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSeasons,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSeasonsTableAnnotationComposer(
            $db: $db,
            $table: $db.localSeasons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> localSourcesRefs<T extends Object>(
    Expression<T> Function($$LocalSourcesTableAnnotationComposer a) f,
  ) {
    final $$LocalSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSources,
      getReferencedColumn: (t) => t.titleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.localSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalTitlesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalTitlesTable,
          LocalTitle,
          $$LocalTitlesTableFilterComposer,
          $$LocalTitlesTableOrderingComposer,
          $$LocalTitlesTableAnnotationComposer,
          $$LocalTitlesTableCreateCompanionBuilder,
          $$LocalTitlesTableUpdateCompanionBuilder,
          (LocalTitle, $$LocalTitlesTableReferences),
          LocalTitle,
          PrefetchHooks Function({
            bool localTitleGenresRefs,
            bool localSeasonsRefs,
            bool localSourcesRefs,
          })
        > {
  $$LocalTitlesTableTableManager(_$CatalogDatabase db, $LocalTitlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTitlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTitlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTitlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> legacyId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> originalTitle = const Value.absent(),
                Value<String> normalizedTitle = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> duration = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<bool> isFeatured = const Value.absent(),
                Value<String?> castMembers = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> writer = const Value.absent(),
                Value<String?> countryCode = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<String?> imdbId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTitlesCompanion(
                id: id,
                legacyId: legacyId,
                mediaType: mediaType,
                title: title,
                originalTitle: originalTitle,
                normalizedTitle: normalizedTitle,
                plot: plot,
                year: year,
                rating: rating,
                duration: duration,
                posterUrl: posterUrl,
                backdropUrl: backdropUrl,
                isFeatured: isFeatured,
                castMembers: castMembers,
                director: director,
                writer: writer,
                countryCode: countryCode,
                tmdbId: tmdbId,
                imdbId: imdbId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> legacyId = const Value.absent(),
                required String mediaType,
                required String title,
                Value<String?> originalTitle = const Value.absent(),
                required String normalizedTitle,
                Value<String?> plot = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> duration = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<bool> isFeatured = const Value.absent(),
                Value<String?> castMembers = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> writer = const Value.absent(),
                Value<String?> countryCode = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<String?> imdbId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTitlesCompanion.insert(
                id: id,
                legacyId: legacyId,
                mediaType: mediaType,
                title: title,
                originalTitle: originalTitle,
                normalizedTitle: normalizedTitle,
                plot: plot,
                year: year,
                rating: rating,
                duration: duration,
                posterUrl: posterUrl,
                backdropUrl: backdropUrl,
                isFeatured: isFeatured,
                castMembers: castMembers,
                director: director,
                writer: writer,
                countryCode: countryCode,
                tmdbId: tmdbId,
                imdbId: imdbId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTitlesTable, LocalTitle>(table),
                  $$LocalTitlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                localTitleGenresRefs = false,
                localSeasonsRefs = false,
                localSourcesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localTitleGenresRefs) db.localTitleGenres,
                    if (localSeasonsRefs) db.localSeasons,
                    if (localSourcesRefs) db.localSources,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localTitleGenresRefs)
                        await $_getPrefetchedData<
                          LocalTitle,
                          $LocalTitlesTable,
                          LocalTitleGenre
                        >(
                          currentTable: table,
                          referencedTable: $$LocalTitlesTableReferences
                              ._localTitleGenresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalTitlesTableReferences(
                                db,
                                table,
                                p0,
                              ).localTitleGenresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.titleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localSeasonsRefs)
                        await $_getPrefetchedData<
                          LocalTitle,
                          $LocalTitlesTable,
                          LocalSeason
                        >(
                          currentTable: table,
                          referencedTable: $$LocalTitlesTableReferences
                              ._localSeasonsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalTitlesTableReferences(
                                db,
                                table,
                                p0,
                              ).localSeasonsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.titleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localSourcesRefs)
                        await $_getPrefetchedData<
                          LocalTitle,
                          $LocalTitlesTable,
                          LocalSource
                        >(
                          currentTable: table,
                          referencedTable: $$LocalTitlesTableReferences
                              ._localSourcesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalTitlesTableReferences(
                                db,
                                table,
                                p0,
                              ).localSourcesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.titleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalTitlesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalTitlesTable,
      LocalTitle,
      $$LocalTitlesTableFilterComposer,
      $$LocalTitlesTableOrderingComposer,
      $$LocalTitlesTableAnnotationComposer,
      $$LocalTitlesTableCreateCompanionBuilder,
      $$LocalTitlesTableUpdateCompanionBuilder,
      (LocalTitle, $$LocalTitlesTableReferences),
      LocalTitle,
      PrefetchHooks Function({
        bool localTitleGenresRefs,
        bool localSeasonsRefs,
        bool localSourcesRefs,
      })
    >;
typedef $$LocalGenresTableCreateCompanionBuilder =
    LocalGenresCompanion Function({
      required String id,
      required String name,
      required String slug,
      Value<int> rowid,
    });
typedef $$LocalGenresTableUpdateCompanionBuilder =
    LocalGenresCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> slug,
      Value<int> rowid,
    });

final class $$LocalGenresTableReferences
    extends BaseReferences<_$CatalogDatabase, $LocalGenresTable, LocalGenre> {
  $$LocalGenresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalTitleGenresTable, List<LocalTitleGenre>>
  _localTitleGenresRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localTitleGenres,
        aliasName: 'local_genres__id__local_title_genres__genre_id',
      );

  $$LocalTitleGenresTableProcessedTableManager get localTitleGenresRefs {
    final manager = $$LocalTitleGenresTableTableManager(
      $_db,
      $_db.localTitleGenres,
    ).filter((f) => f.genreId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localTitleGenresRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalGenresTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalGenresTable> {
  $$LocalGenresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localTitleGenresRefs(
    Expression<bool> Function($$LocalTitleGenresTableFilterComposer f) f,
  ) {
    final $$LocalTitleGenresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localTitleGenres,
      getReferencedColumn: (t) => t.genreId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitleGenresTableFilterComposer(
            $db: $db,
            $table: $db.localTitleGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalGenresTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalGenresTable> {
  $$LocalGenresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalGenresTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalGenresTable> {
  $$LocalGenresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  Expression<T> localTitleGenresRefs<T extends Object>(
    Expression<T> Function($$LocalTitleGenresTableAnnotationComposer a) f,
  ) {
    final $$LocalTitleGenresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localTitleGenres,
      getReferencedColumn: (t) => t.genreId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitleGenresTableAnnotationComposer(
            $db: $db,
            $table: $db.localTitleGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalGenresTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalGenresTable,
          LocalGenre,
          $$LocalGenresTableFilterComposer,
          $$LocalGenresTableOrderingComposer,
          $$LocalGenresTableAnnotationComposer,
          $$LocalGenresTableCreateCompanionBuilder,
          $$LocalGenresTableUpdateCompanionBuilder,
          (LocalGenre, $$LocalGenresTableReferences),
          LocalGenre,
          PrefetchHooks Function({bool localTitleGenresRefs})
        > {
  $$LocalGenresTableTableManager(_$CatalogDatabase db, $LocalGenresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalGenresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalGenresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalGenresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalGenresCompanion(
                id: id,
                name: name,
                slug: slug,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String slug,
                Value<int> rowid = const Value.absent(),
              }) => LocalGenresCompanion.insert(
                id: id,
                name: name,
                slug: slug,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalGenresTable, LocalGenre>(table),
                  $$LocalGenresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localTitleGenresRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localTitleGenresRefs) db.localTitleGenres,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localTitleGenresRefs)
                    await $_getPrefetchedData<
                      LocalGenre,
                      $LocalGenresTable,
                      LocalTitleGenre
                    >(
                      currentTable: table,
                      referencedTable: $$LocalGenresTableReferences
                          ._localTitleGenresRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalGenresTableReferences(
                            db,
                            table,
                            p0,
                          ).localTitleGenresRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.genreId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalGenresTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalGenresTable,
      LocalGenre,
      $$LocalGenresTableFilterComposer,
      $$LocalGenresTableOrderingComposer,
      $$LocalGenresTableAnnotationComposer,
      $$LocalGenresTableCreateCompanionBuilder,
      $$LocalGenresTableUpdateCompanionBuilder,
      (LocalGenre, $$LocalGenresTableReferences),
      LocalGenre,
      PrefetchHooks Function({bool localTitleGenresRefs})
    >;
typedef $$LocalLanguagesTableCreateCompanionBuilder =
    LocalLanguagesCompanion Function({
      required String id,
      required String code,
      required String name,
      Value<int> rowid,
    });
typedef $$LocalLanguagesTableUpdateCompanionBuilder =
    LocalLanguagesCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<int> rowid,
    });

class $$LocalLanguagesTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalLanguagesTable> {
  $$LocalLanguagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalLanguagesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalLanguagesTable> {
  $$LocalLanguagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalLanguagesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalLanguagesTable> {
  $$LocalLanguagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$LocalLanguagesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalLanguagesTable,
          LocalLanguage,
          $$LocalLanguagesTableFilterComposer,
          $$LocalLanguagesTableOrderingComposer,
          $$LocalLanguagesTableAnnotationComposer,
          $$LocalLanguagesTableCreateCompanionBuilder,
          $$LocalLanguagesTableUpdateCompanionBuilder,
          (
            LocalLanguage,
            BaseReferences<
              _$CatalogDatabase,
              $LocalLanguagesTable,
              LocalLanguage
            >,
          ),
          LocalLanguage,
          PrefetchHooks Function()
        > {
  $$LocalLanguagesTableTableManager(
    _$CatalogDatabase db,
    $LocalLanguagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLanguagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLanguagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLanguagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLanguagesCompanion(
                id: id,
                code: code,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => LocalLanguagesCompanion.insert(
                id: id,
                code: code,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalLanguagesTable, LocalLanguage>(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LocalLanguagesTable,
                    LocalLanguage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalLanguagesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalLanguagesTable,
      LocalLanguage,
      $$LocalLanguagesTableFilterComposer,
      $$LocalLanguagesTableOrderingComposer,
      $$LocalLanguagesTableAnnotationComposer,
      $$LocalLanguagesTableCreateCompanionBuilder,
      $$LocalLanguagesTableUpdateCompanionBuilder,
      (
        LocalLanguage,
        BaseReferences<_$CatalogDatabase, $LocalLanguagesTable, LocalLanguage>,
      ),
      LocalLanguage,
      PrefetchHooks Function()
    >;
typedef $$LocalTitleGenresTableCreateCompanionBuilder =
    LocalTitleGenresCompanion Function({
      required String titleId,
      required String genreId,
      Value<int> rowid,
    });
typedef $$LocalTitleGenresTableUpdateCompanionBuilder =
    LocalTitleGenresCompanion Function({
      Value<String> titleId,
      Value<String> genreId,
      Value<int> rowid,
    });

final class $$LocalTitleGenresTableReferences
    extends
        BaseReferences<
          _$CatalogDatabase,
          $LocalTitleGenresTable,
          LocalTitleGenre
        > {
  $$LocalTitleGenresTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalTitlesTable _titleIdTable(_$CatalogDatabase db) => db.localTitles
      .createAlias('local_title_genres__title_id__local_titles__id');

  $$LocalTitlesTableProcessedTableManager get titleId {
    final $_column = $_itemColumn<String>('title_id')!;

    final manager = $$LocalTitlesTableTableManager(
      $_db,
      $_db.localTitles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_titleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LocalGenresTable _genreIdTable(_$CatalogDatabase db) => db.localGenres
      .createAlias('local_title_genres__genre_id__local_genres__id');

  $$LocalGenresTableProcessedTableManager get genreId {
    final $_column = $_itemColumn<String>('genre_id')!;

    final manager = $$LocalGenresTableTableManager(
      $_db,
      $_db.localGenres,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_genreIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalTitleGenresTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalTitleGenresTable> {
  $$LocalTitleGenresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$LocalTitlesTableFilterComposer get titleId {
    final $$LocalTitlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableFilterComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalGenresTableFilterComposer get genreId {
    final $$LocalGenresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.genreId,
      referencedTable: $db.localGenres,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalGenresTableFilterComposer(
            $db: $db,
            $table: $db.localGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTitleGenresTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalTitleGenresTable> {
  $$LocalTitleGenresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$LocalTitlesTableOrderingComposer get titleId {
    final $$LocalTitlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableOrderingComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalGenresTableOrderingComposer get genreId {
    final $$LocalGenresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.genreId,
      referencedTable: $db.localGenres,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalGenresTableOrderingComposer(
            $db: $db,
            $table: $db.localGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTitleGenresTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalTitleGenresTable> {
  $$LocalTitleGenresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$LocalTitlesTableAnnotationComposer get titleId {
    final $$LocalTitlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableAnnotationComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalGenresTableAnnotationComposer get genreId {
    final $$LocalGenresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.genreId,
      referencedTable: $db.localGenres,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalGenresTableAnnotationComposer(
            $db: $db,
            $table: $db.localGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTitleGenresTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalTitleGenresTable,
          LocalTitleGenre,
          $$LocalTitleGenresTableFilterComposer,
          $$LocalTitleGenresTableOrderingComposer,
          $$LocalTitleGenresTableAnnotationComposer,
          $$LocalTitleGenresTableCreateCompanionBuilder,
          $$LocalTitleGenresTableUpdateCompanionBuilder,
          (LocalTitleGenre, $$LocalTitleGenresTableReferences),
          LocalTitleGenre,
          PrefetchHooks Function({bool titleId, bool genreId})
        > {
  $$LocalTitleGenresTableTableManager(
    _$CatalogDatabase db,
    $LocalTitleGenresTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTitleGenresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTitleGenresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTitleGenresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> titleId = const Value.absent(),
                Value<String> genreId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTitleGenresCompanion(
                titleId: titleId,
                genreId: genreId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String titleId,
                required String genreId,
                Value<int> rowid = const Value.absent(),
              }) => LocalTitleGenresCompanion.insert(
                titleId: titleId,
                genreId: genreId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTitleGenresTable, LocalTitleGenre>(table),
                  $$LocalTitleGenresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({titleId = false, genreId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (titleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.titleId,
                                referencedTable:
                                    $$LocalTitleGenresTableReferences
                                        ._titleIdTable(db),
                                referencedColumn:
                                    $$LocalTitleGenresTableReferences
                                        ._titleIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (genreId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.genreId,
                                referencedTable:
                                    $$LocalTitleGenresTableReferences
                                        ._genreIdTable(db),
                                referencedColumn:
                                    $$LocalTitleGenresTableReferences
                                        ._genreIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalTitleGenresTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalTitleGenresTable,
      LocalTitleGenre,
      $$LocalTitleGenresTableFilterComposer,
      $$LocalTitleGenresTableOrderingComposer,
      $$LocalTitleGenresTableAnnotationComposer,
      $$LocalTitleGenresTableCreateCompanionBuilder,
      $$LocalTitleGenresTableUpdateCompanionBuilder,
      (LocalTitleGenre, $$LocalTitleGenresTableReferences),
      LocalTitleGenre,
      PrefetchHooks Function({bool titleId, bool genreId})
    >;
typedef $$LocalSeasonsTableCreateCompanionBuilder =
    LocalSeasonsCompanion Function({
      required String id,
      required String titleId,
      required int seasonNumber,
      Value<String?> name,
      Value<String?> plot,
      Value<String?> posterUrl,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$LocalSeasonsTableUpdateCompanionBuilder =
    LocalSeasonsCompanion Function({
      Value<String> id,
      Value<String> titleId,
      Value<int> seasonNumber,
      Value<String?> name,
      Value<String?> plot,
      Value<String?> posterUrl,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$LocalSeasonsTableReferences
    extends BaseReferences<_$CatalogDatabase, $LocalSeasonsTable, LocalSeason> {
  $$LocalSeasonsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalTitlesTable _titleIdTable(_$CatalogDatabase db) =>
      db.localTitles.createAlias('local_seasons__title_id__local_titles__id');

  $$LocalTitlesTableProcessedTableManager get titleId {
    final $_column = $_itemColumn<String>('title_id')!;

    final manager = $$LocalTitlesTableTableManager(
      $_db,
      $_db.localTitles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_titleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LocalEpisodesTable, List<LocalEpisode>>
  _localEpisodesRefsTable(_$CatalogDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localEpisodes,
        aliasName: 'local_seasons__id__local_episodes__season_id',
      );

  $$LocalEpisodesTableProcessedTableManager get localEpisodesRefs {
    final manager = $$LocalEpisodesTableTableManager(
      $_db,
      $_db.localEpisodes,
    ).filter((f) => f.seasonId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localEpisodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalSeasonsTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalSeasonsTable> {
  $$LocalSeasonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalTitlesTableFilterComposer get titleId {
    final $$LocalTitlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableFilterComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> localEpisodesRefs(
    Expression<bool> Function($$LocalEpisodesTableFilterComposer f) f,
  ) {
    final $$LocalEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localEpisodes,
      getReferencedColumn: (t) => t.seasonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.localEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalSeasonsTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalSeasonsTable> {
  $$LocalSeasonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalTitlesTableOrderingComposer get titleId {
    final $$LocalTitlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableOrderingComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSeasonsTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalSeasonsTable> {
  $$LocalSeasonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$LocalTitlesTableAnnotationComposer get titleId {
    final $$LocalTitlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableAnnotationComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> localEpisodesRefs<T extends Object>(
    Expression<T> Function($$LocalEpisodesTableAnnotationComposer a) f,
  ) {
    final $$LocalEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localEpisodes,
      getReferencedColumn: (t) => t.seasonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.localEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalSeasonsTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalSeasonsTable,
          LocalSeason,
          $$LocalSeasonsTableFilterComposer,
          $$LocalSeasonsTableOrderingComposer,
          $$LocalSeasonsTableAnnotationComposer,
          $$LocalSeasonsTableCreateCompanionBuilder,
          $$LocalSeasonsTableUpdateCompanionBuilder,
          (LocalSeason, $$LocalSeasonsTableReferences),
          LocalSeason,
          PrefetchHooks Function({bool titleId, bool localEpisodesRefs})
        > {
  $$LocalSeasonsTableTableManager(
    _$CatalogDatabase db,
    $LocalSeasonsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSeasonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSeasonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSeasonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<int> seasonNumber = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSeasonsCompanion(
                id: id,
                titleId: titleId,
                seasonNumber: seasonNumber,
                name: name,
                plot: plot,
                posterUrl: posterUrl,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String titleId,
                required int seasonNumber,
                Value<String?> name = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSeasonsCompanion.insert(
                id: id,
                titleId: titleId,
                seasonNumber: seasonNumber,
                name: name,
                plot: plot,
                posterUrl: posterUrl,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSeasonsTable, LocalSeason>(table),
                  $$LocalSeasonsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({titleId = false, localEpisodesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localEpisodesRefs) db.localEpisodes,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (titleId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.titleId,
                                    referencedTable:
                                        $$LocalSeasonsTableReferences
                                            ._titleIdTable(db),
                                    referencedColumn:
                                        $$LocalSeasonsTableReferences
                                            ._titleIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localEpisodesRefs)
                        await $_getPrefetchedData<
                          LocalSeason,
                          $LocalSeasonsTable,
                          LocalEpisode
                        >(
                          currentTable: table,
                          referencedTable: $$LocalSeasonsTableReferences
                              ._localEpisodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalSeasonsTableReferences(
                                db,
                                table,
                                p0,
                              ).localEpisodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.seasonId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalSeasonsTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalSeasonsTable,
      LocalSeason,
      $$LocalSeasonsTableFilterComposer,
      $$LocalSeasonsTableOrderingComposer,
      $$LocalSeasonsTableAnnotationComposer,
      $$LocalSeasonsTableCreateCompanionBuilder,
      $$LocalSeasonsTableUpdateCompanionBuilder,
      (LocalSeason, $$LocalSeasonsTableReferences),
      LocalSeason,
      PrefetchHooks Function({bool titleId, bool localEpisodesRefs})
    >;
typedef $$LocalEpisodesTableCreateCompanionBuilder =
    LocalEpisodesCompanion Function({
      required String id,
      required String seasonId,
      required int episodeNumber,
      required String title,
      Value<String?> plot,
      Value<String?> duration,
      Value<String?> stillUrl,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$LocalEpisodesTableUpdateCompanionBuilder =
    LocalEpisodesCompanion Function({
      Value<String> id,
      Value<String> seasonId,
      Value<int> episodeNumber,
      Value<String> title,
      Value<String?> plot,
      Value<String?> duration,
      Value<String?> stillUrl,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$LocalEpisodesTableReferences
    extends
        BaseReferences<_$CatalogDatabase, $LocalEpisodesTable, LocalEpisode> {
  $$LocalEpisodesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalSeasonsTable _seasonIdTable(_$CatalogDatabase db) => db
      .localSeasons
      .createAlias('local_episodes__season_id__local_seasons__id');

  $$LocalSeasonsTableProcessedTableManager get seasonId {
    final $_column = $_itemColumn<String>('season_id')!;

    final manager = $$LocalSeasonsTableTableManager(
      $_db,
      $_db.localSeasons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seasonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LocalSourcesTable, List<LocalSource>>
  _localSourcesRefsTable(_$CatalogDatabase db) => MultiTypedResultKey.fromTable(
    db.localSources,
    aliasName: 'local_episodes__id__local_sources__episode_id',
  );

  $$LocalSourcesTableProcessedTableManager get localSourcesRefs {
    final manager = $$LocalSourcesTableTableManager(
      $_db,
      $_db.localSources,
    ).filter((f) => f.episodeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localSourcesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalEpisodesTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalEpisodesTable> {
  $$LocalEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stillUrl => $composableBuilder(
    column: $table.stillUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalSeasonsTableFilterComposer get seasonId {
    final $$LocalSeasonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seasonId,
      referencedTable: $db.localSeasons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSeasonsTableFilterComposer(
            $db: $db,
            $table: $db.localSeasons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> localSourcesRefs(
    Expression<bool> Function($$LocalSourcesTableFilterComposer f) f,
  ) {
    final $$LocalSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSources,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSourcesTableFilterComposer(
            $db: $db,
            $table: $db.localSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalEpisodesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalEpisodesTable> {
  $$LocalEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stillUrl => $composableBuilder(
    column: $table.stillUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalSeasonsTableOrderingComposer get seasonId {
    final $$LocalSeasonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seasonId,
      referencedTable: $db.localSeasons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSeasonsTableOrderingComposer(
            $db: $db,
            $table: $db.localSeasons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalEpisodesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalEpisodesTable> {
  $$LocalEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get stillUrl =>
      $composableBuilder(column: $table.stillUrl, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$LocalSeasonsTableAnnotationComposer get seasonId {
    final $$LocalSeasonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seasonId,
      referencedTable: $db.localSeasons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSeasonsTableAnnotationComposer(
            $db: $db,
            $table: $db.localSeasons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> localSourcesRefs<T extends Object>(
    Expression<T> Function($$LocalSourcesTableAnnotationComposer a) f,
  ) {
    final $$LocalSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSources,
      getReferencedColumn: (t) => t.episodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.localSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalEpisodesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalEpisodesTable,
          LocalEpisode,
          $$LocalEpisodesTableFilterComposer,
          $$LocalEpisodesTableOrderingComposer,
          $$LocalEpisodesTableAnnotationComposer,
          $$LocalEpisodesTableCreateCompanionBuilder,
          $$LocalEpisodesTableUpdateCompanionBuilder,
          (LocalEpisode, $$LocalEpisodesTableReferences),
          LocalEpisode,
          PrefetchHooks Function({bool seasonId, bool localSourcesRefs})
        > {
  $$LocalEpisodesTableTableManager(
    _$CatalogDatabase db,
    $LocalEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> seasonId = const Value.absent(),
                Value<int> episodeNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> duration = const Value.absent(),
                Value<String?> stillUrl = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEpisodesCompanion(
                id: id,
                seasonId: seasonId,
                episodeNumber: episodeNumber,
                title: title,
                plot: plot,
                duration: duration,
                stillUrl: stillUrl,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String seasonId,
                required int episodeNumber,
                required String title,
                Value<String?> plot = const Value.absent(),
                Value<String?> duration = const Value.absent(),
                Value<String?> stillUrl = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEpisodesCompanion.insert(
                id: id,
                seasonId: seasonId,
                episodeNumber: episodeNumber,
                title: title,
                plot: plot,
                duration: duration,
                stillUrl: stillUrl,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalEpisodesTable, LocalEpisode>(table),
                  $$LocalEpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({seasonId = false, localSourcesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localSourcesRefs) db.localSources,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (seasonId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.seasonId,
                                    referencedTable:
                                        $$LocalEpisodesTableReferences
                                            ._seasonIdTable(db),
                                    referencedColumn:
                                        $$LocalEpisodesTableReferences
                                            ._seasonIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localSourcesRefs)
                        await $_getPrefetchedData<
                          LocalEpisode,
                          $LocalEpisodesTable,
                          LocalSource
                        >(
                          currentTable: table,
                          referencedTable: $$LocalEpisodesTableReferences
                              ._localSourcesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalEpisodesTableReferences(
                                db,
                                table,
                                p0,
                              ).localSourcesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.episodeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalEpisodesTable,
      LocalEpisode,
      $$LocalEpisodesTableFilterComposer,
      $$LocalEpisodesTableOrderingComposer,
      $$LocalEpisodesTableAnnotationComposer,
      $$LocalEpisodesTableCreateCompanionBuilder,
      $$LocalEpisodesTableUpdateCompanionBuilder,
      (LocalEpisode, $$LocalEpisodesTableReferences),
      LocalEpisode,
      PrefetchHooks Function({bool seasonId, bool localSourcesRefs})
    >;
typedef $$LocalSourcesTableCreateCompanionBuilder =
    LocalSourcesCompanion Function({
      required String id,
      Value<String?> titleId,
      Value<String?> episodeId,
      required String name,
      required String url,
      Value<String?> language,
      Value<int> orderIndex,
      Value<String> status,
      Value<bool> requiresWebview,
      Value<String?> refererUrl,
      Value<String?> originUrl,
      Value<String?> userAgentProfile,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$LocalSourcesTableUpdateCompanionBuilder =
    LocalSourcesCompanion Function({
      Value<String> id,
      Value<String?> titleId,
      Value<String?> episodeId,
      Value<String> name,
      Value<String> url,
      Value<String?> language,
      Value<int> orderIndex,
      Value<String> status,
      Value<bool> requiresWebview,
      Value<String?> refererUrl,
      Value<String?> originUrl,
      Value<String?> userAgentProfile,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$LocalSourcesTableReferences
    extends BaseReferences<_$CatalogDatabase, $LocalSourcesTable, LocalSource> {
  $$LocalSourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalTitlesTable _titleIdTable(_$CatalogDatabase db) =>
      db.localTitles.createAlias('local_sources__title_id__local_titles__id');

  $$LocalTitlesTableProcessedTableManager? get titleId {
    final $_column = $_itemColumn<String>('title_id');
    if ($_column == null) return null;
    final manager = $$LocalTitlesTableTableManager(
      $_db,
      $_db.localTitles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_titleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LocalEpisodesTable _episodeIdTable(_$CatalogDatabase db) => db
      .localEpisodes
      .createAlias('local_sources__episode_id__local_episodes__id');

  $$LocalEpisodesTableProcessedTableManager? get episodeId {
    final $_column = $_itemColumn<String>('episode_id');
    if ($_column == null) return null;
    final manager = $$LocalEpisodesTableTableManager(
      $_db,
      $_db.localEpisodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_episodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalSourcesTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalSourcesTable> {
  $$LocalSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresWebview => $composableBuilder(
    column: $table.requiresWebview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refererUrl => $composableBuilder(
    column: $table.refererUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originUrl => $composableBuilder(
    column: $table.originUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userAgentProfile => $composableBuilder(
    column: $table.userAgentProfile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalTitlesTableFilterComposer get titleId {
    final $$LocalTitlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableFilterComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalEpisodesTableFilterComposer get episodeId {
    final $$LocalEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.localEpisodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.localEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSourcesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalSourcesTable> {
  $$LocalSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresWebview => $composableBuilder(
    column: $table.requiresWebview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refererUrl => $composableBuilder(
    column: $table.refererUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originUrl => $composableBuilder(
    column: $table.originUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userAgentProfile => $composableBuilder(
    column: $table.userAgentProfile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalTitlesTableOrderingComposer get titleId {
    final $$LocalTitlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableOrderingComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalEpisodesTableOrderingComposer get episodeId {
    final $$LocalEpisodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.localEpisodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEpisodesTableOrderingComposer(
            $db: $db,
            $table: $db.localEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSourcesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalSourcesTable> {
  $$LocalSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get requiresWebview => $composableBuilder(
    column: $table.requiresWebview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refererUrl => $composableBuilder(
    column: $table.refererUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originUrl =>
      $composableBuilder(column: $table.originUrl, builder: (column) => column);

  GeneratedColumn<String> get userAgentProfile => $composableBuilder(
    column: $table.userAgentProfile,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$LocalTitlesTableAnnotationComposer get titleId {
    final $$LocalTitlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.titleId,
      referencedTable: $db.localTitles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTitlesTableAnnotationComposer(
            $db: $db,
            $table: $db.localTitles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalEpisodesTableAnnotationComposer get episodeId {
    final $$LocalEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.episodeId,
      referencedTable: $db.localEpisodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.localEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSourcesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalSourcesTable,
          LocalSource,
          $$LocalSourcesTableFilterComposer,
          $$LocalSourcesTableOrderingComposer,
          $$LocalSourcesTableAnnotationComposer,
          $$LocalSourcesTableCreateCompanionBuilder,
          $$LocalSourcesTableUpdateCompanionBuilder,
          (LocalSource, $$LocalSourcesTableReferences),
          LocalSource,
          PrefetchHooks Function({bool titleId, bool episodeId})
        > {
  $$LocalSourcesTableTableManager(
    _$CatalogDatabase db,
    $LocalSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> titleId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> requiresWebview = const Value.absent(),
                Value<String?> refererUrl = const Value.absent(),
                Value<String?> originUrl = const Value.absent(),
                Value<String?> userAgentProfile = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSourcesCompanion(
                id: id,
                titleId: titleId,
                episodeId: episodeId,
                name: name,
                url: url,
                language: language,
                orderIndex: orderIndex,
                status: status,
                requiresWebview: requiresWebview,
                refererUrl: refererUrl,
                originUrl: originUrl,
                userAgentProfile: userAgentProfile,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> titleId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                required String name,
                required String url,
                Value<String?> language = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> requiresWebview = const Value.absent(),
                Value<String?> refererUrl = const Value.absent(),
                Value<String?> originUrl = const Value.absent(),
                Value<String?> userAgentProfile = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSourcesCompanion.insert(
                id: id,
                titleId: titleId,
                episodeId: episodeId,
                name: name,
                url: url,
                language: language,
                orderIndex: orderIndex,
                status: status,
                requiresWebview: requiresWebview,
                refererUrl: refererUrl,
                originUrl: originUrl,
                userAgentProfile: userAgentProfile,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSourcesTable, LocalSource>(table),
                  $$LocalSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({titleId = false, episodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (titleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.titleId,
                                referencedTable: $$LocalSourcesTableReferences
                                    ._titleIdTable(db),
                                referencedColumn: $$LocalSourcesTableReferences
                                    ._titleIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (episodeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.episodeId,
                                referencedTable: $$LocalSourcesTableReferences
                                    ._episodeIdTable(db),
                                referencedColumn: $$LocalSourcesTableReferences
                                    ._episodeIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalSourcesTable,
      LocalSource,
      $$LocalSourcesTableFilterComposer,
      $$LocalSourcesTableOrderingComposer,
      $$LocalSourcesTableAnnotationComposer,
      $$LocalSourcesTableCreateCompanionBuilder,
      $$LocalSourcesTableUpdateCompanionBuilder,
      (LocalSource, $$LocalSourcesTableReferences),
      LocalSource,
      PrefetchHooks Function({bool titleId, bool episodeId})
    >;
typedef $$CatalogSyncStatesTableCreateCompanionBuilder =
    CatalogSyncStatesCompanion Function({
      required String syncKey,
      Value<int> lastCatalogRevision,
      required DateTime lastSyncTimestamp,
      Value<int> totalSynced,
      Value<int> rowid,
    });
typedef $$CatalogSyncStatesTableUpdateCompanionBuilder =
    CatalogSyncStatesCompanion Function({
      Value<String> syncKey,
      Value<int> lastCatalogRevision,
      Value<DateTime> lastSyncTimestamp,
      Value<int> totalSynced,
      Value<int> rowid,
    });

class $$CatalogSyncStatesTableFilterComposer
    extends Composer<_$CatalogDatabase, $CatalogSyncStatesTable> {
  $$CatalogSyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncKey => $composableBuilder(
    column: $table.syncKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastCatalogRevision => $composableBuilder(
    column: $table.lastCatalogRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncTimestamp => $composableBuilder(
    column: $table.lastSyncTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalSynced => $composableBuilder(
    column: $table.totalSynced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogSyncStatesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $CatalogSyncStatesTable> {
  $$CatalogSyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncKey => $composableBuilder(
    column: $table.syncKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastCatalogRevision => $composableBuilder(
    column: $table.lastCatalogRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncTimestamp => $composableBuilder(
    column: $table.lastSyncTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalSynced => $composableBuilder(
    column: $table.totalSynced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogSyncStatesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $CatalogSyncStatesTable> {
  $$CatalogSyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncKey =>
      $composableBuilder(column: $table.syncKey, builder: (column) => column);

  GeneratedColumn<int> get lastCatalogRevision => $composableBuilder(
    column: $table.lastCatalogRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncTimestamp => $composableBuilder(
    column: $table.lastSyncTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalSynced => $composableBuilder(
    column: $table.totalSynced,
    builder: (column) => column,
  );
}

class $$CatalogSyncStatesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $CatalogSyncStatesTable,
          CatalogSyncState,
          $$CatalogSyncStatesTableFilterComposer,
          $$CatalogSyncStatesTableOrderingComposer,
          $$CatalogSyncStatesTableAnnotationComposer,
          $$CatalogSyncStatesTableCreateCompanionBuilder,
          $$CatalogSyncStatesTableUpdateCompanionBuilder,
          (
            CatalogSyncState,
            BaseReferences<
              _$CatalogDatabase,
              $CatalogSyncStatesTable,
              CatalogSyncState
            >,
          ),
          CatalogSyncState,
          PrefetchHooks Function()
        > {
  $$CatalogSyncStatesTableTableManager(
    _$CatalogDatabase db,
    $CatalogSyncStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogSyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogSyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogSyncStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> syncKey = const Value.absent(),
                Value<int> lastCatalogRevision = const Value.absent(),
                Value<DateTime> lastSyncTimestamp = const Value.absent(),
                Value<int> totalSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogSyncStatesCompanion(
                syncKey: syncKey,
                lastCatalogRevision: lastCatalogRevision,
                lastSyncTimestamp: lastSyncTimestamp,
                totalSynced: totalSynced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncKey,
                Value<int> lastCatalogRevision = const Value.absent(),
                required DateTime lastSyncTimestamp,
                Value<int> totalSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogSyncStatesCompanion.insert(
                syncKey: syncKey,
                lastCatalogRevision: lastCatalogRevision,
                lastSyncTimestamp: lastSyncTimestamp,
                totalSynced: totalSynced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogSyncStatesTable, CatalogSyncState>(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $CatalogSyncStatesTable,
                    CatalogSyncState
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogSyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $CatalogSyncStatesTable,
      CatalogSyncState,
      $$CatalogSyncStatesTableFilterComposer,
      $$CatalogSyncStatesTableOrderingComposer,
      $$CatalogSyncStatesTableAnnotationComposer,
      $$CatalogSyncStatesTableCreateCompanionBuilder,
      $$CatalogSyncStatesTableUpdateCompanionBuilder,
      (
        CatalogSyncState,
        BaseReferences<
          _$CatalogDatabase,
          $CatalogSyncStatesTable,
          CatalogSyncState
        >,
      ),
      CatalogSyncState,
      PrefetchHooks Function()
    >;

class $CatalogDatabaseManager {
  final _$CatalogDatabase _db;
  $CatalogDatabaseManager(this._db);
  $$LocalTitlesTableTableManager get localTitles =>
      $$LocalTitlesTableTableManager(_db, _db.localTitles);
  $$LocalGenresTableTableManager get localGenres =>
      $$LocalGenresTableTableManager(_db, _db.localGenres);
  $$LocalLanguagesTableTableManager get localLanguages =>
      $$LocalLanguagesTableTableManager(_db, _db.localLanguages);
  $$LocalTitleGenresTableTableManager get localTitleGenres =>
      $$LocalTitleGenresTableTableManager(_db, _db.localTitleGenres);
  $$LocalSeasonsTableTableManager get localSeasons =>
      $$LocalSeasonsTableTableManager(_db, _db.localSeasons);
  $$LocalEpisodesTableTableManager get localEpisodes =>
      $$LocalEpisodesTableTableManager(_db, _db.localEpisodes);
  $$LocalSourcesTableTableManager get localSources =>
      $$LocalSourcesTableTableManager(_db, _db.localSources);
  $$CatalogSyncStatesTableTableManager get catalogSyncStates =>
      $$CatalogSyncStatesTableTableManager(_db, _db.catalogSyncStates);
}
