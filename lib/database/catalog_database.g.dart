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
  static const VerificationMeta _healthStatusMeta = const VerificationMeta(
    'healthStatus',
  );
  @override
  late final GeneratedColumn<String> healthStatus = GeneratedColumn<String>(
    'health_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _healthLastErrorMeta = const VerificationMeta(
    'healthLastError',
  );
  @override
  late final GeneratedColumn<String> healthLastError = GeneratedColumn<String>(
    'health_last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _healthHttpCodeMeta = const VerificationMeta(
    'healthHttpCode',
  );
  @override
  late final GeneratedColumn<int> healthHttpCode = GeneratedColumn<int>(
    'health_http_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _healthConsecutiveFailuresMeta =
      const VerificationMeta('healthConsecutiveFailures');
  @override
  late final GeneratedColumn<int> healthConsecutiveFailures =
      GeneratedColumn<int>(
        'health_consecutive_failures',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _healthFirstFailureAtMeta =
      const VerificationMeta('healthFirstFailureAt');
  @override
  late final GeneratedColumn<DateTime> healthFirstFailureAt =
      GeneratedColumn<DateTime>(
        'health_first_failure_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _healthLastSuccessAtMeta =
      const VerificationMeta('healthLastSuccessAt');
  @override
  late final GeneratedColumn<DateTime> healthLastSuccessAt =
      GeneratedColumn<DateTime>(
        'health_last_success_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _healthLastCheckMeta = const VerificationMeta(
    'healthLastCheck',
  );
  @override
  late final GeneratedColumn<DateTime> healthLastCheck =
      GeneratedColumn<DateTime>(
        'health_last_check',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _healthLastCheckRunIdMeta =
      const VerificationMeta('healthLastCheckRunId');
  @override
  late final GeneratedColumn<String> healthLastCheckRunId =
      GeneratedColumn<String>(
        'health_last_check_run_id',
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
    healthStatus,
    healthLastError,
    healthHttpCode,
    healthConsecutiveFailures,
    healthFirstFailureAt,
    healthLastSuccessAt,
    healthLastCheck,
    healthLastCheckRunId,
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
    if (data.containsKey('health_status')) {
      context.handle(
        _healthStatusMeta,
        healthStatus.isAcceptableOrUnknown(
          data['health_status']!,
          _healthStatusMeta,
        ),
      );
    }
    if (data.containsKey('health_last_error')) {
      context.handle(
        _healthLastErrorMeta,
        healthLastError.isAcceptableOrUnknown(
          data['health_last_error']!,
          _healthLastErrorMeta,
        ),
      );
    }
    if (data.containsKey('health_http_code')) {
      context.handle(
        _healthHttpCodeMeta,
        healthHttpCode.isAcceptableOrUnknown(
          data['health_http_code']!,
          _healthHttpCodeMeta,
        ),
      );
    }
    if (data.containsKey('health_consecutive_failures')) {
      context.handle(
        _healthConsecutiveFailuresMeta,
        healthConsecutiveFailures.isAcceptableOrUnknown(
          data['health_consecutive_failures']!,
          _healthConsecutiveFailuresMeta,
        ),
      );
    }
    if (data.containsKey('health_first_failure_at')) {
      context.handle(
        _healthFirstFailureAtMeta,
        healthFirstFailureAt.isAcceptableOrUnknown(
          data['health_first_failure_at']!,
          _healthFirstFailureAtMeta,
        ),
      );
    }
    if (data.containsKey('health_last_success_at')) {
      context.handle(
        _healthLastSuccessAtMeta,
        healthLastSuccessAt.isAcceptableOrUnknown(
          data['health_last_success_at']!,
          _healthLastSuccessAtMeta,
        ),
      );
    }
    if (data.containsKey('health_last_check')) {
      context.handle(
        _healthLastCheckMeta,
        healthLastCheck.isAcceptableOrUnknown(
          data['health_last_check']!,
          _healthLastCheckMeta,
        ),
      );
    }
    if (data.containsKey('health_last_check_run_id')) {
      context.handle(
        _healthLastCheckRunIdMeta,
        healthLastCheckRunId.isAcceptableOrUnknown(
          data['health_last_check_run_id']!,
          _healthLastCheckRunIdMeta,
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
      healthStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health_status'],
      )!,
      healthLastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health_last_error'],
      ),
      healthHttpCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}health_http_code'],
      ),
      healthConsecutiveFailures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}health_consecutive_failures'],
      )!,
      healthFirstFailureAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}health_first_failure_at'],
      ),
      healthLastSuccessAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}health_last_success_at'],
      ),
      healthLastCheck: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}health_last_check'],
      ),
      healthLastCheckRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health_last_check_run_id'],
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
  final String healthStatus;
  final String? healthLastError;
  final int? healthHttpCode;
  final int healthConsecutiveFailures;
  final DateTime? healthFirstFailureAt;
  final DateTime? healthLastSuccessAt;
  final DateTime? healthLastCheck;
  final String? healthLastCheckRunId;
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
    required this.healthStatus,
    this.healthLastError,
    this.healthHttpCode,
    required this.healthConsecutiveFailures,
    this.healthFirstFailureAt,
    this.healthLastSuccessAt,
    this.healthLastCheck,
    this.healthLastCheckRunId,
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
    map['health_status'] = Variable<String>(healthStatus);
    if (!nullToAbsent || healthLastError != null) {
      map['health_last_error'] = Variable<String>(healthLastError);
    }
    if (!nullToAbsent || healthHttpCode != null) {
      map['health_http_code'] = Variable<int>(healthHttpCode);
    }
    map['health_consecutive_failures'] = Variable<int>(
      healthConsecutiveFailures,
    );
    if (!nullToAbsent || healthFirstFailureAt != null) {
      map['health_first_failure_at'] = Variable<DateTime>(healthFirstFailureAt);
    }
    if (!nullToAbsent || healthLastSuccessAt != null) {
      map['health_last_success_at'] = Variable<DateTime>(healthLastSuccessAt);
    }
    if (!nullToAbsent || healthLastCheck != null) {
      map['health_last_check'] = Variable<DateTime>(healthLastCheck);
    }
    if (!nullToAbsent || healthLastCheckRunId != null) {
      map['health_last_check_run_id'] = Variable<String>(healthLastCheckRunId);
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
      healthStatus: Value(healthStatus),
      healthLastError: healthLastError == null && nullToAbsent
          ? const Value.absent()
          : Value(healthLastError),
      healthHttpCode: healthHttpCode == null && nullToAbsent
          ? const Value.absent()
          : Value(healthHttpCode),
      healthConsecutiveFailures: Value(healthConsecutiveFailures),
      healthFirstFailureAt: healthFirstFailureAt == null && nullToAbsent
          ? const Value.absent()
          : Value(healthFirstFailureAt),
      healthLastSuccessAt: healthLastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(healthLastSuccessAt),
      healthLastCheck: healthLastCheck == null && nullToAbsent
          ? const Value.absent()
          : Value(healthLastCheck),
      healthLastCheckRunId: healthLastCheckRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(healthLastCheckRunId),
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
      healthStatus: serializer.fromJson<String>(json['healthStatus']),
      healthLastError: serializer.fromJson<String?>(json['healthLastError']),
      healthHttpCode: serializer.fromJson<int?>(json['healthHttpCode']),
      healthConsecutiveFailures: serializer.fromJson<int>(
        json['healthConsecutiveFailures'],
      ),
      healthFirstFailureAt: serializer.fromJson<DateTime?>(
        json['healthFirstFailureAt'],
      ),
      healthLastSuccessAt: serializer.fromJson<DateTime?>(
        json['healthLastSuccessAt'],
      ),
      healthLastCheck: serializer.fromJson<DateTime?>(json['healthLastCheck']),
      healthLastCheckRunId: serializer.fromJson<String?>(
        json['healthLastCheckRunId'],
      ),
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
      'healthStatus': serializer.toJson<String>(healthStatus),
      'healthLastError': serializer.toJson<String?>(healthLastError),
      'healthHttpCode': serializer.toJson<int?>(healthHttpCode),
      'healthConsecutiveFailures': serializer.toJson<int>(
        healthConsecutiveFailures,
      ),
      'healthFirstFailureAt': serializer.toJson<DateTime?>(
        healthFirstFailureAt,
      ),
      'healthLastSuccessAt': serializer.toJson<DateTime?>(healthLastSuccessAt),
      'healthLastCheck': serializer.toJson<DateTime?>(healthLastCheck),
      'healthLastCheckRunId': serializer.toJson<String?>(healthLastCheckRunId),
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
    String? healthStatus,
    Value<String?> healthLastError = const Value.absent(),
    Value<int?> healthHttpCode = const Value.absent(),
    int? healthConsecutiveFailures,
    Value<DateTime?> healthFirstFailureAt = const Value.absent(),
    Value<DateTime?> healthLastSuccessAt = const Value.absent(),
    Value<DateTime?> healthLastCheck = const Value.absent(),
    Value<String?> healthLastCheckRunId = const Value.absent(),
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
    healthStatus: healthStatus ?? this.healthStatus,
    healthLastError: healthLastError.present
        ? healthLastError.value
        : this.healthLastError,
    healthHttpCode: healthHttpCode.present
        ? healthHttpCode.value
        : this.healthHttpCode,
    healthConsecutiveFailures:
        healthConsecutiveFailures ?? this.healthConsecutiveFailures,
    healthFirstFailureAt: healthFirstFailureAt.present
        ? healthFirstFailureAt.value
        : this.healthFirstFailureAt,
    healthLastSuccessAt: healthLastSuccessAt.present
        ? healthLastSuccessAt.value
        : this.healthLastSuccessAt,
    healthLastCheck: healthLastCheck.present
        ? healthLastCheck.value
        : this.healthLastCheck,
    healthLastCheckRunId: healthLastCheckRunId.present
        ? healthLastCheckRunId.value
        : this.healthLastCheckRunId,
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
      healthStatus: data.healthStatus.present
          ? data.healthStatus.value
          : this.healthStatus,
      healthLastError: data.healthLastError.present
          ? data.healthLastError.value
          : this.healthLastError,
      healthHttpCode: data.healthHttpCode.present
          ? data.healthHttpCode.value
          : this.healthHttpCode,
      healthConsecutiveFailures: data.healthConsecutiveFailures.present
          ? data.healthConsecutiveFailures.value
          : this.healthConsecutiveFailures,
      healthFirstFailureAt: data.healthFirstFailureAt.present
          ? data.healthFirstFailureAt.value
          : this.healthFirstFailureAt,
      healthLastSuccessAt: data.healthLastSuccessAt.present
          ? data.healthLastSuccessAt.value
          : this.healthLastSuccessAt,
      healthLastCheck: data.healthLastCheck.present
          ? data.healthLastCheck.value
          : this.healthLastCheck,
      healthLastCheckRunId: data.healthLastCheckRunId.present
          ? data.healthLastCheckRunId.value
          : this.healthLastCheckRunId,
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
          ..write('healthStatus: $healthStatus, ')
          ..write('healthLastError: $healthLastError, ')
          ..write('healthHttpCode: $healthHttpCode, ')
          ..write('healthConsecutiveFailures: $healthConsecutiveFailures, ')
          ..write('healthFirstFailureAt: $healthFirstFailureAt, ')
          ..write('healthLastSuccessAt: $healthLastSuccessAt, ')
          ..write('healthLastCheck: $healthLastCheck, ')
          ..write('healthLastCheckRunId: $healthLastCheckRunId, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    healthStatus,
    healthLastError,
    healthHttpCode,
    healthConsecutiveFailures,
    healthFirstFailureAt,
    healthLastSuccessAt,
    healthLastCheck,
    healthLastCheckRunId,
    isDeleted,
  ]);
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
          other.healthStatus == this.healthStatus &&
          other.healthLastError == this.healthLastError &&
          other.healthHttpCode == this.healthHttpCode &&
          other.healthConsecutiveFailures == this.healthConsecutiveFailures &&
          other.healthFirstFailureAt == this.healthFirstFailureAt &&
          other.healthLastSuccessAt == this.healthLastSuccessAt &&
          other.healthLastCheck == this.healthLastCheck &&
          other.healthLastCheckRunId == this.healthLastCheckRunId &&
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
  final Value<String> healthStatus;
  final Value<String?> healthLastError;
  final Value<int?> healthHttpCode;
  final Value<int> healthConsecutiveFailures;
  final Value<DateTime?> healthFirstFailureAt;
  final Value<DateTime?> healthLastSuccessAt;
  final Value<DateTime?> healthLastCheck;
  final Value<String?> healthLastCheckRunId;
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
    this.healthStatus = const Value.absent(),
    this.healthLastError = const Value.absent(),
    this.healthHttpCode = const Value.absent(),
    this.healthConsecutiveFailures = const Value.absent(),
    this.healthFirstFailureAt = const Value.absent(),
    this.healthLastSuccessAt = const Value.absent(),
    this.healthLastCheck = const Value.absent(),
    this.healthLastCheckRunId = const Value.absent(),
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
    this.healthStatus = const Value.absent(),
    this.healthLastError = const Value.absent(),
    this.healthHttpCode = const Value.absent(),
    this.healthConsecutiveFailures = const Value.absent(),
    this.healthFirstFailureAt = const Value.absent(),
    this.healthLastSuccessAt = const Value.absent(),
    this.healthLastCheck = const Value.absent(),
    this.healthLastCheckRunId = const Value.absent(),
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
    Expression<String>? healthStatus,
    Expression<String>? healthLastError,
    Expression<int>? healthHttpCode,
    Expression<int>? healthConsecutiveFailures,
    Expression<DateTime>? healthFirstFailureAt,
    Expression<DateTime>? healthLastSuccessAt,
    Expression<DateTime>? healthLastCheck,
    Expression<String>? healthLastCheckRunId,
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
      if (healthStatus != null) 'health_status': healthStatus,
      if (healthLastError != null) 'health_last_error': healthLastError,
      if (healthHttpCode != null) 'health_http_code': healthHttpCode,
      if (healthConsecutiveFailures != null)
        'health_consecutive_failures': healthConsecutiveFailures,
      if (healthFirstFailureAt != null)
        'health_first_failure_at': healthFirstFailureAt,
      if (healthLastSuccessAt != null)
        'health_last_success_at': healthLastSuccessAt,
      if (healthLastCheck != null) 'health_last_check': healthLastCheck,
      if (healthLastCheckRunId != null)
        'health_last_check_run_id': healthLastCheckRunId,
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
    Value<String>? healthStatus,
    Value<String?>? healthLastError,
    Value<int?>? healthHttpCode,
    Value<int>? healthConsecutiveFailures,
    Value<DateTime?>? healthFirstFailureAt,
    Value<DateTime?>? healthLastSuccessAt,
    Value<DateTime?>? healthLastCheck,
    Value<String?>? healthLastCheckRunId,
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
      healthStatus: healthStatus ?? this.healthStatus,
      healthLastError: healthLastError ?? this.healthLastError,
      healthHttpCode: healthHttpCode ?? this.healthHttpCode,
      healthConsecutiveFailures:
          healthConsecutiveFailures ?? this.healthConsecutiveFailures,
      healthFirstFailureAt: healthFirstFailureAt ?? this.healthFirstFailureAt,
      healthLastSuccessAt: healthLastSuccessAt ?? this.healthLastSuccessAt,
      healthLastCheck: healthLastCheck ?? this.healthLastCheck,
      healthLastCheckRunId: healthLastCheckRunId ?? this.healthLastCheckRunId,
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
    if (healthStatus.present) {
      map['health_status'] = Variable<String>(healthStatus.value);
    }
    if (healthLastError.present) {
      map['health_last_error'] = Variable<String>(healthLastError.value);
    }
    if (healthHttpCode.present) {
      map['health_http_code'] = Variable<int>(healthHttpCode.value);
    }
    if (healthConsecutiveFailures.present) {
      map['health_consecutive_failures'] = Variable<int>(
        healthConsecutiveFailures.value,
      );
    }
    if (healthFirstFailureAt.present) {
      map['health_first_failure_at'] = Variable<DateTime>(
        healthFirstFailureAt.value,
      );
    }
    if (healthLastSuccessAt.present) {
      map['health_last_success_at'] = Variable<DateTime>(
        healthLastSuccessAt.value,
      );
    }
    if (healthLastCheck.present) {
      map['health_last_check'] = Variable<DateTime>(healthLastCheck.value);
    }
    if (healthLastCheckRunId.present) {
      map['health_last_check_run_id'] = Variable<String>(
        healthLastCheckRunId.value,
      );
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
          ..write('healthStatus: $healthStatus, ')
          ..write('healthLastError: $healthLastError, ')
          ..write('healthHttpCode: $healthHttpCode, ')
          ..write('healthConsecutiveFailures: $healthConsecutiveFailures, ')
          ..write('healthFirstFailureAt: $healthFirstFailureAt, ')
          ..write('healthLastSuccessAt: $healthLastSuccessAt, ')
          ..write('healthLastCheck: $healthLastCheck, ')
          ..write('healthLastCheckRunId: $healthLastCheckRunId, ')
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

class $LocalProfileFavoritesTable extends LocalProfileFavorites
    with TableInfo<$LocalProfileFavoritesTable, LocalProfileFavorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfileFavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentKeyMeta = const VerificationMeta(
    'contentKey',
  );
  @override
  late final GeneratedColumn<String> contentKey = GeneratedColumn<String>(
    'content_key',
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
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    contentKey,
    titleId,
    isFavorite,
    updatedAt,
    serverRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profile_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfileFavorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('content_key')) {
      context.handle(
        _contentKeyMeta,
        contentKey.isAcceptableOrUnknown(data['content_key']!, _contentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contentKeyMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, contentKey};
  @override
  LocalProfileFavorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfileFavorite(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      contentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_key'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
    );
  }

  @override
  $LocalProfileFavoritesTable createAlias(String alias) {
    return $LocalProfileFavoritesTable(attachedDatabase, alias);
  }
}

class LocalProfileFavorite extends DataClass
    implements Insertable<LocalProfileFavorite> {
  final String profileId;
  final String contentKey;
  final String? titleId;
  final bool isFavorite;
  final DateTime updatedAt;
  final int serverRevision;
  const LocalProfileFavorite({
    required this.profileId,
    required this.contentKey,
    this.titleId,
    required this.isFavorite,
    required this.updatedAt,
    required this.serverRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['content_key'] = Variable<String>(contentKey);
    if (!nullToAbsent || titleId != null) {
      map['title_id'] = Variable<String>(titleId);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['server_revision'] = Variable<int>(serverRevision);
    return map;
  }

  LocalProfileFavoritesCompanion toCompanion(bool nullToAbsent) {
    return LocalProfileFavoritesCompanion(
      profileId: Value(profileId),
      contentKey: Value(contentKey),
      titleId: titleId == null && nullToAbsent
          ? const Value.absent()
          : Value(titleId),
      isFavorite: Value(isFavorite),
      updatedAt: Value(updatedAt),
      serverRevision: Value(serverRevision),
    );
  }

  factory LocalProfileFavorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfileFavorite(
      profileId: serializer.fromJson<String>(json['profileId']),
      contentKey: serializer.fromJson<String>(json['contentKey']),
      titleId: serializer.fromJson<String?>(json['titleId']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'contentKey': serializer.toJson<String>(contentKey),
      'titleId': serializer.toJson<String?>(titleId),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
    };
  }

  LocalProfileFavorite copyWith({
    String? profileId,
    String? contentKey,
    Value<String?> titleId = const Value.absent(),
    bool? isFavorite,
    DateTime? updatedAt,
    int? serverRevision,
  }) => LocalProfileFavorite(
    profileId: profileId ?? this.profileId,
    contentKey: contentKey ?? this.contentKey,
    titleId: titleId.present ? titleId.value : this.titleId,
    isFavorite: isFavorite ?? this.isFavorite,
    updatedAt: updatedAt ?? this.updatedAt,
    serverRevision: serverRevision ?? this.serverRevision,
  );
  LocalProfileFavorite copyWithCompanion(LocalProfileFavoritesCompanion data) {
    return LocalProfileFavorite(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      contentKey: data.contentKey.present
          ? data.contentKey.value
          : this.contentKey,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileFavorite(')
          ..write('profileId: $profileId, ')
          ..write('contentKey: $contentKey, ')
          ..write('titleId: $titleId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverRevision: $serverRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    contentKey,
    titleId,
    isFavorite,
    updatedAt,
    serverRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfileFavorite &&
          other.profileId == this.profileId &&
          other.contentKey == this.contentKey &&
          other.titleId == this.titleId &&
          other.isFavorite == this.isFavorite &&
          other.updatedAt == this.updatedAt &&
          other.serverRevision == this.serverRevision);
}

class LocalProfileFavoritesCompanion
    extends UpdateCompanion<LocalProfileFavorite> {
  final Value<String> profileId;
  final Value<String> contentKey;
  final Value<String?> titleId;
  final Value<bool> isFavorite;
  final Value<DateTime> updatedAt;
  final Value<int> serverRevision;
  final Value<int> rowid;
  const LocalProfileFavoritesCompanion({
    this.profileId = const Value.absent(),
    this.contentKey = const Value.absent(),
    this.titleId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfileFavoritesCompanion.insert({
    required String profileId,
    required String contentKey,
    this.titleId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    required DateTime updatedAt,
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       contentKey = Value(contentKey),
       updatedAt = Value(updatedAt);
  static Insertable<LocalProfileFavorite> custom({
    Expression<String>? profileId,
    Expression<String>? contentKey,
    Expression<String>? titleId,
    Expression<bool>? isFavorite,
    Expression<DateTime>? updatedAt,
    Expression<int>? serverRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (contentKey != null) 'content_key': contentKey,
      if (titleId != null) 'title_id': titleId,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfileFavoritesCompanion copyWith({
    Value<String>? profileId,
    Value<String>? contentKey,
    Value<String?>? titleId,
    Value<bool>? isFavorite,
    Value<DateTime>? updatedAt,
    Value<int>? serverRevision,
    Value<int>? rowid,
  }) {
    return LocalProfileFavoritesCompanion(
      profileId: profileId ?? this.profileId,
      contentKey: contentKey ?? this.contentKey,
      titleId: titleId ?? this.titleId,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (contentKey.present) {
      map['content_key'] = Variable<String>(contentKey.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileFavoritesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('contentKey: $contentKey, ')
          ..write('titleId: $titleId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProfilePlaybackProgressTable extends LocalProfilePlaybackProgress
    with
        TableInfo<
          $LocalProfilePlaybackProgressTable,
          LocalProfilePlaybackProgressData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfilePlaybackProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentKeyMeta = const VerificationMeta(
    'contentKey',
  );
  @override
  late final GeneratedColumn<String> contentKey = GeneratedColumn<String>(
    'content_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playbackSessionIdMeta = const VerificationMeta(
    'playbackSessionId',
  );
  @override
  late final GeneratedColumn<String> playbackSessionId =
      GeneratedColumn<String>(
        'playback_session_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fractionMeta = const VerificationMeta(
    'fraction',
  );
  @override
  late final GeneratedColumn<double> fraction = GeneratedColumn<double>(
    'fraction',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastWatchedAtMeta = const VerificationMeta(
    'lastWatchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastWatchedAt =
      GeneratedColumn<DateTime>(
        'last_watched_at',
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    contentKey,
    playbackSessionId,
    titleId,
    episodeId,
    positionMs,
    durationMs,
    fraction,
    isCompleted,
    lastWatchedAt,
    updatedAt,
    deletedAt,
    serverRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profile_playback_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfilePlaybackProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('content_key')) {
      context.handle(
        _contentKeyMeta,
        contentKey.isAcceptableOrUnknown(data['content_key']!, _contentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contentKeyMeta);
    }
    if (data.containsKey('playback_session_id')) {
      context.handle(
        _playbackSessionIdMeta,
        playbackSessionId.isAcceptableOrUnknown(
          data['playback_session_id']!,
          _playbackSessionIdMeta,
        ),
      );
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
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('fraction')) {
      context.handle(
        _fractionMeta,
        fraction.isAcceptableOrUnknown(data['fraction']!, _fractionMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('last_watched_at')) {
      context.handle(
        _lastWatchedAtMeta,
        lastWatchedAt.isAcceptableOrUnknown(
          data['last_watched_at']!,
          _lastWatchedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWatchedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, contentKey};
  @override
  LocalProfilePlaybackProgressData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfilePlaybackProgressData(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      contentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_key'],
      )!,
      playbackSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playback_session_id'],
      ),
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      ),
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      fraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fraction'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      lastWatchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_watched_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
    );
  }

  @override
  $LocalProfilePlaybackProgressTable createAlias(String alias) {
    return $LocalProfilePlaybackProgressTable(attachedDatabase, alias);
  }
}

class LocalProfilePlaybackProgressData extends DataClass
    implements Insertable<LocalProfilePlaybackProgressData> {
  final String profileId;
  final String contentKey;
  final String? playbackSessionId;
  final String? titleId;
  final String? episodeId;
  final int positionMs;
  final int durationMs;
  final double fraction;
  final bool isCompleted;
  final DateTime lastWatchedAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int serverRevision;
  const LocalProfilePlaybackProgressData({
    required this.profileId,
    required this.contentKey,
    this.playbackSessionId,
    this.titleId,
    this.episodeId,
    required this.positionMs,
    required this.durationMs,
    required this.fraction,
    required this.isCompleted,
    required this.lastWatchedAt,
    required this.updatedAt,
    this.deletedAt,
    required this.serverRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['content_key'] = Variable<String>(contentKey);
    if (!nullToAbsent || playbackSessionId != null) {
      map['playback_session_id'] = Variable<String>(playbackSessionId);
    }
    if (!nullToAbsent || titleId != null) {
      map['title_id'] = Variable<String>(titleId);
    }
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<String>(episodeId);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['fraction'] = Variable<double>(fraction);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['last_watched_at'] = Variable<DateTime>(lastWatchedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['server_revision'] = Variable<int>(serverRevision);
    return map;
  }

  LocalProfilePlaybackProgressCompanion toCompanion(bool nullToAbsent) {
    return LocalProfilePlaybackProgressCompanion(
      profileId: Value(profileId),
      contentKey: Value(contentKey),
      playbackSessionId: playbackSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(playbackSessionId),
      titleId: titleId == null && nullToAbsent
          ? const Value.absent()
          : Value(titleId),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      fraction: Value(fraction),
      isCompleted: Value(isCompleted),
      lastWatchedAt: Value(lastWatchedAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverRevision: Value(serverRevision),
    );
  }

  factory LocalProfilePlaybackProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfilePlaybackProgressData(
      profileId: serializer.fromJson<String>(json['profileId']),
      contentKey: serializer.fromJson<String>(json['contentKey']),
      playbackSessionId: serializer.fromJson<String?>(
        json['playbackSessionId'],
      ),
      titleId: serializer.fromJson<String?>(json['titleId']),
      episodeId: serializer.fromJson<String?>(json['episodeId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      fraction: serializer.fromJson<double>(json['fraction']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      lastWatchedAt: serializer.fromJson<DateTime>(json['lastWatchedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'contentKey': serializer.toJson<String>(contentKey),
      'playbackSessionId': serializer.toJson<String?>(playbackSessionId),
      'titleId': serializer.toJson<String?>(titleId),
      'episodeId': serializer.toJson<String?>(episodeId),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'fraction': serializer.toJson<double>(fraction),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'lastWatchedAt': serializer.toJson<DateTime>(lastWatchedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
    };
  }

  LocalProfilePlaybackProgressData copyWith({
    String? profileId,
    String? contentKey,
    Value<String?> playbackSessionId = const Value.absent(),
    Value<String?> titleId = const Value.absent(),
    Value<String?> episodeId = const Value.absent(),
    int? positionMs,
    int? durationMs,
    double? fraction,
    bool? isCompleted,
    DateTime? lastWatchedAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? serverRevision,
  }) => LocalProfilePlaybackProgressData(
    profileId: profileId ?? this.profileId,
    contentKey: contentKey ?? this.contentKey,
    playbackSessionId: playbackSessionId.present
        ? playbackSessionId.value
        : this.playbackSessionId,
    titleId: titleId.present ? titleId.value : this.titleId,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    fraction: fraction ?? this.fraction,
    isCompleted: isCompleted ?? this.isCompleted,
    lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverRevision: serverRevision ?? this.serverRevision,
  );
  LocalProfilePlaybackProgressData copyWithCompanion(
    LocalProfilePlaybackProgressCompanion data,
  ) {
    return LocalProfilePlaybackProgressData(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      contentKey: data.contentKey.present
          ? data.contentKey.value
          : this.contentKey,
      playbackSessionId: data.playbackSessionId.present
          ? data.playbackSessionId.value
          : this.playbackSessionId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      fraction: data.fraction.present ? data.fraction.value : this.fraction,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      lastWatchedAt: data.lastWatchedAt.present
          ? data.lastWatchedAt.value
          : this.lastWatchedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilePlaybackProgressData(')
          ..write('profileId: $profileId, ')
          ..write('contentKey: $contentKey, ')
          ..write('playbackSessionId: $playbackSessionId, ')
          ..write('titleId: $titleId, ')
          ..write('episodeId: $episodeId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('fraction: $fraction, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('lastWatchedAt: $lastWatchedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverRevision: $serverRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    contentKey,
    playbackSessionId,
    titleId,
    episodeId,
    positionMs,
    durationMs,
    fraction,
    isCompleted,
    lastWatchedAt,
    updatedAt,
    deletedAt,
    serverRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfilePlaybackProgressData &&
          other.profileId == this.profileId &&
          other.contentKey == this.contentKey &&
          other.playbackSessionId == this.playbackSessionId &&
          other.titleId == this.titleId &&
          other.episodeId == this.episodeId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.fraction == this.fraction &&
          other.isCompleted == this.isCompleted &&
          other.lastWatchedAt == this.lastWatchedAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.serverRevision == this.serverRevision);
}

class LocalProfilePlaybackProgressCompanion
    extends UpdateCompanion<LocalProfilePlaybackProgressData> {
  final Value<String> profileId;
  final Value<String> contentKey;
  final Value<String?> playbackSessionId;
  final Value<String?> titleId;
  final Value<String?> episodeId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<double> fraction;
  final Value<bool> isCompleted;
  final Value<DateTime> lastWatchedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> serverRevision;
  final Value<int> rowid;
  const LocalProfilePlaybackProgressCompanion({
    this.profileId = const Value.absent(),
    this.contentKey = const Value.absent(),
    this.playbackSessionId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fraction = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfilePlaybackProgressCompanion.insert({
    required String profileId,
    required String contentKey,
    this.playbackSessionId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fraction = const Value.absent(),
    this.isCompleted = const Value.absent(),
    required DateTime lastWatchedAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       contentKey = Value(contentKey),
       lastWatchedAt = Value(lastWatchedAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalProfilePlaybackProgressData> custom({
    Expression<String>? profileId,
    Expression<String>? contentKey,
    Expression<String>? playbackSessionId,
    Expression<String>? titleId,
    Expression<String>? episodeId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<double>? fraction,
    Expression<bool>? isCompleted,
    Expression<DateTime>? lastWatchedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? serverRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (contentKey != null) 'content_key': contentKey,
      if (playbackSessionId != null) 'playback_session_id': playbackSessionId,
      if (titleId != null) 'title_id': titleId,
      if (episodeId != null) 'episode_id': episodeId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (fraction != null) 'fraction': fraction,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (lastWatchedAt != null) 'last_watched_at': lastWatchedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfilePlaybackProgressCompanion copyWith({
    Value<String>? profileId,
    Value<String>? contentKey,
    Value<String?>? playbackSessionId,
    Value<String?>? titleId,
    Value<String?>? episodeId,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<double>? fraction,
    Value<bool>? isCompleted,
    Value<DateTime>? lastWatchedAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? serverRevision,
    Value<int>? rowid,
  }) {
    return LocalProfilePlaybackProgressCompanion(
      profileId: profileId ?? this.profileId,
      contentKey: contentKey ?? this.contentKey,
      playbackSessionId: playbackSessionId ?? this.playbackSessionId,
      titleId: titleId ?? this.titleId,
      episodeId: episodeId ?? this.episodeId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      fraction: fraction ?? this.fraction,
      isCompleted: isCompleted ?? this.isCompleted,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (contentKey.present) {
      map['content_key'] = Variable<String>(contentKey.value);
    }
    if (playbackSessionId.present) {
      map['playback_session_id'] = Variable<String>(playbackSessionId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (fraction.present) {
      map['fraction'] = Variable<double>(fraction.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (lastWatchedAt.present) {
      map['last_watched_at'] = Variable<DateTime>(lastWatchedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilePlaybackProgressCompanion(')
          ..write('profileId: $profileId, ')
          ..write('contentKey: $contentKey, ')
          ..write('playbackSessionId: $playbackSessionId, ')
          ..write('titleId: $titleId, ')
          ..write('episodeId: $episodeId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('fraction: $fraction, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('lastWatchedAt: $lastWatchedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProfileHistoryTable extends LocalProfileHistory
    with TableInfo<$LocalProfileHistoryTable, LocalProfileHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfileHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playbackSessionIdMeta = const VerificationMeta(
    'playbackSessionId',
  );
  @override
  late final GeneratedColumn<String> playbackSessionId =
      GeneratedColumn<String>(
        'playback_session_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _contentKeyMeta = const VerificationMeta(
    'contentKey',
  );
  @override
  late final GeneratedColumn<String> contentKey = GeneratedColumn<String>(
    'content_key',
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
  );
  static const VerificationMeta _stoppedAtMsMeta = const VerificationMeta(
    'stoppedAtMs',
  );
  @override
  late final GeneratedColumn<int> stoppedAtMs = GeneratedColumn<int>(
    'stopped_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fractionMeta = const VerificationMeta(
    'fraction',
  );
  @override
  late final GeneratedColumn<double> fraction = GeneratedColumn<double>(
    'fraction',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _watchedAtMeta = const VerificationMeta(
    'watchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> watchedAt = GeneratedColumn<DateTime>(
    'watched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    playbackSessionId,
    contentKey,
    titleId,
    episodeId,
    stoppedAtMs,
    durationMs,
    fraction,
    isCompleted,
    watchedAt,
    serverRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profile_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfileHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('playback_session_id')) {
      context.handle(
        _playbackSessionIdMeta,
        playbackSessionId.isAcceptableOrUnknown(
          data['playback_session_id']!,
          _playbackSessionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playbackSessionIdMeta);
    }
    if (data.containsKey('content_key')) {
      context.handle(
        _contentKeyMeta,
        contentKey.isAcceptableOrUnknown(data['content_key']!, _contentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contentKeyMeta);
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
    if (data.containsKey('stopped_at_ms')) {
      context.handle(
        _stoppedAtMsMeta,
        stoppedAtMs.isAcceptableOrUnknown(
          data['stopped_at_ms']!,
          _stoppedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('fraction')) {
      context.handle(
        _fractionMeta,
        fraction.isAcceptableOrUnknown(data['fraction']!, _fractionMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('watched_at')) {
      context.handle(
        _watchedAtMeta,
        watchedAt.isAcceptableOrUnknown(data['watched_at']!, _watchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_watchedAtMeta);
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProfileHistoryData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfileHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      playbackSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playback_session_id'],
      )!,
      contentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_key'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      ),
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      ),
      stoppedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stopped_at_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      fraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fraction'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      watchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}watched_at'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
    );
  }

  @override
  $LocalProfileHistoryTable createAlias(String alias) {
    return $LocalProfileHistoryTable(attachedDatabase, alias);
  }
}

class LocalProfileHistoryData extends DataClass
    implements Insertable<LocalProfileHistoryData> {
  final String id;
  final String profileId;
  final String playbackSessionId;
  final String contentKey;
  final String? titleId;
  final String? episodeId;
  final int stoppedAtMs;
  final int durationMs;
  final double fraction;
  final bool isCompleted;
  final DateTime watchedAt;
  final int serverRevision;
  const LocalProfileHistoryData({
    required this.id,
    required this.profileId,
    required this.playbackSessionId,
    required this.contentKey,
    this.titleId,
    this.episodeId,
    required this.stoppedAtMs,
    required this.durationMs,
    required this.fraction,
    required this.isCompleted,
    required this.watchedAt,
    required this.serverRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['playback_session_id'] = Variable<String>(playbackSessionId);
    map['content_key'] = Variable<String>(contentKey);
    if (!nullToAbsent || titleId != null) {
      map['title_id'] = Variable<String>(titleId);
    }
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<String>(episodeId);
    }
    map['stopped_at_ms'] = Variable<int>(stoppedAtMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['fraction'] = Variable<double>(fraction);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['watched_at'] = Variable<DateTime>(watchedAt);
    map['server_revision'] = Variable<int>(serverRevision);
    return map;
  }

  LocalProfileHistoryCompanion toCompanion(bool nullToAbsent) {
    return LocalProfileHistoryCompanion(
      id: Value(id),
      profileId: Value(profileId),
      playbackSessionId: Value(playbackSessionId),
      contentKey: Value(contentKey),
      titleId: titleId == null && nullToAbsent
          ? const Value.absent()
          : Value(titleId),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      stoppedAtMs: Value(stoppedAtMs),
      durationMs: Value(durationMs),
      fraction: Value(fraction),
      isCompleted: Value(isCompleted),
      watchedAt: Value(watchedAt),
      serverRevision: Value(serverRevision),
    );
  }

  factory LocalProfileHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfileHistoryData(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      playbackSessionId: serializer.fromJson<String>(json['playbackSessionId']),
      contentKey: serializer.fromJson<String>(json['contentKey']),
      titleId: serializer.fromJson<String?>(json['titleId']),
      episodeId: serializer.fromJson<String?>(json['episodeId']),
      stoppedAtMs: serializer.fromJson<int>(json['stoppedAtMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      fraction: serializer.fromJson<double>(json['fraction']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      watchedAt: serializer.fromJson<DateTime>(json['watchedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'playbackSessionId': serializer.toJson<String>(playbackSessionId),
      'contentKey': serializer.toJson<String>(contentKey),
      'titleId': serializer.toJson<String?>(titleId),
      'episodeId': serializer.toJson<String?>(episodeId),
      'stoppedAtMs': serializer.toJson<int>(stoppedAtMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'fraction': serializer.toJson<double>(fraction),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'watchedAt': serializer.toJson<DateTime>(watchedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
    };
  }

  LocalProfileHistoryData copyWith({
    String? id,
    String? profileId,
    String? playbackSessionId,
    String? contentKey,
    Value<String?> titleId = const Value.absent(),
    Value<String?> episodeId = const Value.absent(),
    int? stoppedAtMs,
    int? durationMs,
    double? fraction,
    bool? isCompleted,
    DateTime? watchedAt,
    int? serverRevision,
  }) => LocalProfileHistoryData(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    playbackSessionId: playbackSessionId ?? this.playbackSessionId,
    contentKey: contentKey ?? this.contentKey,
    titleId: titleId.present ? titleId.value : this.titleId,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    stoppedAtMs: stoppedAtMs ?? this.stoppedAtMs,
    durationMs: durationMs ?? this.durationMs,
    fraction: fraction ?? this.fraction,
    isCompleted: isCompleted ?? this.isCompleted,
    watchedAt: watchedAt ?? this.watchedAt,
    serverRevision: serverRevision ?? this.serverRevision,
  );
  LocalProfileHistoryData copyWithCompanion(LocalProfileHistoryCompanion data) {
    return LocalProfileHistoryData(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      playbackSessionId: data.playbackSessionId.present
          ? data.playbackSessionId.value
          : this.playbackSessionId,
      contentKey: data.contentKey.present
          ? data.contentKey.value
          : this.contentKey,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      stoppedAtMs: data.stoppedAtMs.present
          ? data.stoppedAtMs.value
          : this.stoppedAtMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      fraction: data.fraction.present ? data.fraction.value : this.fraction,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      watchedAt: data.watchedAt.present ? data.watchedAt.value : this.watchedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileHistoryData(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('playbackSessionId: $playbackSessionId, ')
          ..write('contentKey: $contentKey, ')
          ..write('titleId: $titleId, ')
          ..write('episodeId: $episodeId, ')
          ..write('stoppedAtMs: $stoppedAtMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('fraction: $fraction, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('serverRevision: $serverRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    playbackSessionId,
    contentKey,
    titleId,
    episodeId,
    stoppedAtMs,
    durationMs,
    fraction,
    isCompleted,
    watchedAt,
    serverRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfileHistoryData &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.playbackSessionId == this.playbackSessionId &&
          other.contentKey == this.contentKey &&
          other.titleId == this.titleId &&
          other.episodeId == this.episodeId &&
          other.stoppedAtMs == this.stoppedAtMs &&
          other.durationMs == this.durationMs &&
          other.fraction == this.fraction &&
          other.isCompleted == this.isCompleted &&
          other.watchedAt == this.watchedAt &&
          other.serverRevision == this.serverRevision);
}

class LocalProfileHistoryCompanion
    extends UpdateCompanion<LocalProfileHistoryData> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> playbackSessionId;
  final Value<String> contentKey;
  final Value<String?> titleId;
  final Value<String?> episodeId;
  final Value<int> stoppedAtMs;
  final Value<int> durationMs;
  final Value<double> fraction;
  final Value<bool> isCompleted;
  final Value<DateTime> watchedAt;
  final Value<int> serverRevision;
  final Value<int> rowid;
  const LocalProfileHistoryCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.playbackSessionId = const Value.absent(),
    this.contentKey = const Value.absent(),
    this.titleId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.stoppedAtMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fraction = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfileHistoryCompanion.insert({
    required String id,
    required String profileId,
    required String playbackSessionId,
    required String contentKey,
    this.titleId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.stoppedAtMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fraction = const Value.absent(),
    this.isCompleted = const Value.absent(),
    required DateTime watchedAt,
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       playbackSessionId = Value(playbackSessionId),
       contentKey = Value(contentKey),
       watchedAt = Value(watchedAt);
  static Insertable<LocalProfileHistoryData> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? playbackSessionId,
    Expression<String>? contentKey,
    Expression<String>? titleId,
    Expression<String>? episodeId,
    Expression<int>? stoppedAtMs,
    Expression<int>? durationMs,
    Expression<double>? fraction,
    Expression<bool>? isCompleted,
    Expression<DateTime>? watchedAt,
    Expression<int>? serverRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (playbackSessionId != null) 'playback_session_id': playbackSessionId,
      if (contentKey != null) 'content_key': contentKey,
      if (titleId != null) 'title_id': titleId,
      if (episodeId != null) 'episode_id': episodeId,
      if (stoppedAtMs != null) 'stopped_at_ms': stoppedAtMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (fraction != null) 'fraction': fraction,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (watchedAt != null) 'watched_at': watchedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfileHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? playbackSessionId,
    Value<String>? contentKey,
    Value<String?>? titleId,
    Value<String?>? episodeId,
    Value<int>? stoppedAtMs,
    Value<int>? durationMs,
    Value<double>? fraction,
    Value<bool>? isCompleted,
    Value<DateTime>? watchedAt,
    Value<int>? serverRevision,
    Value<int>? rowid,
  }) {
    return LocalProfileHistoryCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      playbackSessionId: playbackSessionId ?? this.playbackSessionId,
      contentKey: contentKey ?? this.contentKey,
      titleId: titleId ?? this.titleId,
      episodeId: episodeId ?? this.episodeId,
      stoppedAtMs: stoppedAtMs ?? this.stoppedAtMs,
      durationMs: durationMs ?? this.durationMs,
      fraction: fraction ?? this.fraction,
      isCompleted: isCompleted ?? this.isCompleted,
      watchedAt: watchedAt ?? this.watchedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (playbackSessionId.present) {
      map['playback_session_id'] = Variable<String>(playbackSessionId.value);
    }
    if (contentKey.present) {
      map['content_key'] = Variable<String>(contentKey.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (stoppedAtMs.present) {
      map['stopped_at_ms'] = Variable<int>(stoppedAtMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (fraction.present) {
      map['fraction'] = Variable<double>(fraction.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (watchedAt.present) {
      map['watched_at'] = Variable<DateTime>(watchedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileHistoryCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('playbackSessionId: $playbackSessionId, ')
          ..write('contentKey: $contentKey, ')
          ..write('titleId: $titleId, ')
          ..write('episodeId: $episodeId, ')
          ..write('stoppedAtMs: $stoppedAtMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('fraction: $fraction, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProfilePreferencesTable extends LocalProfilePreferences
    with TableInfo<$LocalProfilePreferencesTable, LocalProfilePreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfilePreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preferredAudioLanguageMeta =
      const VerificationMeta('preferredAudioLanguage');
  @override
  late final GeneratedColumn<String> preferredAudioLanguage =
      GeneratedColumn<String>(
        'preferred_audio_language',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preferredSubtitleLanguageMeta =
      const VerificationMeta('preferredSubtitleLanguage');
  @override
  late final GeneratedColumn<String> preferredSubtitleLanguage =
      GeneratedColumn<String>(
        'preferred_subtitle_language',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _subtitlesEnabledMeta = const VerificationMeta(
    'subtitlesEnabled',
  );
  @override
  late final GeneratedColumn<bool> subtitlesEnabled = GeneratedColumn<bool>(
    'subtitles_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("subtitles_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _autoPlayNextMeta = const VerificationMeta(
    'autoPlayNext',
  );
  @override
  late final GeneratedColumn<bool> autoPlayNext = GeneratedColumn<bool>(
    'auto_play_next',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_play_next" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    preferredAudioLanguage,
    preferredSubtitleLanguage,
    subtitlesEnabled,
    autoPlayNext,
    updatedAt,
    serverRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profile_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfilePreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('preferred_audio_language')) {
      context.handle(
        _preferredAudioLanguageMeta,
        preferredAudioLanguage.isAcceptableOrUnknown(
          data['preferred_audio_language']!,
          _preferredAudioLanguageMeta,
        ),
      );
    }
    if (data.containsKey('preferred_subtitle_language')) {
      context.handle(
        _preferredSubtitleLanguageMeta,
        preferredSubtitleLanguage.isAcceptableOrUnknown(
          data['preferred_subtitle_language']!,
          _preferredSubtitleLanguageMeta,
        ),
      );
    }
    if (data.containsKey('subtitles_enabled')) {
      context.handle(
        _subtitlesEnabledMeta,
        subtitlesEnabled.isAcceptableOrUnknown(
          data['subtitles_enabled']!,
          _subtitlesEnabledMeta,
        ),
      );
    }
    if (data.containsKey('auto_play_next')) {
      context.handle(
        _autoPlayNextMeta,
        autoPlayNext.isAcceptableOrUnknown(
          data['auto_play_next']!,
          _autoPlayNextMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId};
  @override
  LocalProfilePreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfilePreference(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      preferredAudioLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_audio_language'],
      ),
      preferredSubtitleLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_subtitle_language'],
      ),
      subtitlesEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}subtitles_enabled'],
      )!,
      autoPlayNext: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_play_next'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
    );
  }

  @override
  $LocalProfilePreferencesTable createAlias(String alias) {
    return $LocalProfilePreferencesTable(attachedDatabase, alias);
  }
}

class LocalProfilePreference extends DataClass
    implements Insertable<LocalProfilePreference> {
  final String profileId;
  final String? preferredAudioLanguage;
  final String? preferredSubtitleLanguage;
  final bool subtitlesEnabled;
  final bool autoPlayNext;
  final DateTime updatedAt;
  final int serverRevision;
  const LocalProfilePreference({
    required this.profileId,
    this.preferredAudioLanguage,
    this.preferredSubtitleLanguage,
    required this.subtitlesEnabled,
    required this.autoPlayNext,
    required this.updatedAt,
    required this.serverRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || preferredAudioLanguage != null) {
      map['preferred_audio_language'] = Variable<String>(
        preferredAudioLanguage,
      );
    }
    if (!nullToAbsent || preferredSubtitleLanguage != null) {
      map['preferred_subtitle_language'] = Variable<String>(
        preferredSubtitleLanguage,
      );
    }
    map['subtitles_enabled'] = Variable<bool>(subtitlesEnabled);
    map['auto_play_next'] = Variable<bool>(autoPlayNext);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['server_revision'] = Variable<int>(serverRevision);
    return map;
  }

  LocalProfilePreferencesCompanion toCompanion(bool nullToAbsent) {
    return LocalProfilePreferencesCompanion(
      profileId: Value(profileId),
      preferredAudioLanguage: preferredAudioLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredAudioLanguage),
      preferredSubtitleLanguage:
          preferredSubtitleLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredSubtitleLanguage),
      subtitlesEnabled: Value(subtitlesEnabled),
      autoPlayNext: Value(autoPlayNext),
      updatedAt: Value(updatedAt),
      serverRevision: Value(serverRevision),
    );
  }

  factory LocalProfilePreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfilePreference(
      profileId: serializer.fromJson<String>(json['profileId']),
      preferredAudioLanguage: serializer.fromJson<String?>(
        json['preferredAudioLanguage'],
      ),
      preferredSubtitleLanguage: serializer.fromJson<String?>(
        json['preferredSubtitleLanguage'],
      ),
      subtitlesEnabled: serializer.fromJson<bool>(json['subtitlesEnabled']),
      autoPlayNext: serializer.fromJson<bool>(json['autoPlayNext']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'preferredAudioLanguage': serializer.toJson<String?>(
        preferredAudioLanguage,
      ),
      'preferredSubtitleLanguage': serializer.toJson<String?>(
        preferredSubtitleLanguage,
      ),
      'subtitlesEnabled': serializer.toJson<bool>(subtitlesEnabled),
      'autoPlayNext': serializer.toJson<bool>(autoPlayNext),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
    };
  }

  LocalProfilePreference copyWith({
    String? profileId,
    Value<String?> preferredAudioLanguage = const Value.absent(),
    Value<String?> preferredSubtitleLanguage = const Value.absent(),
    bool? subtitlesEnabled,
    bool? autoPlayNext,
    DateTime? updatedAt,
    int? serverRevision,
  }) => LocalProfilePreference(
    profileId: profileId ?? this.profileId,
    preferredAudioLanguage: preferredAudioLanguage.present
        ? preferredAudioLanguage.value
        : this.preferredAudioLanguage,
    preferredSubtitleLanguage: preferredSubtitleLanguage.present
        ? preferredSubtitleLanguage.value
        : this.preferredSubtitleLanguage,
    subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
    autoPlayNext: autoPlayNext ?? this.autoPlayNext,
    updatedAt: updatedAt ?? this.updatedAt,
    serverRevision: serverRevision ?? this.serverRevision,
  );
  LocalProfilePreference copyWithCompanion(
    LocalProfilePreferencesCompanion data,
  ) {
    return LocalProfilePreference(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      preferredAudioLanguage: data.preferredAudioLanguage.present
          ? data.preferredAudioLanguage.value
          : this.preferredAudioLanguage,
      preferredSubtitleLanguage: data.preferredSubtitleLanguage.present
          ? data.preferredSubtitleLanguage.value
          : this.preferredSubtitleLanguage,
      subtitlesEnabled: data.subtitlesEnabled.present
          ? data.subtitlesEnabled.value
          : this.subtitlesEnabled,
      autoPlayNext: data.autoPlayNext.present
          ? data.autoPlayNext.value
          : this.autoPlayNext,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilePreference(')
          ..write('profileId: $profileId, ')
          ..write('preferredAudioLanguage: $preferredAudioLanguage, ')
          ..write('preferredSubtitleLanguage: $preferredSubtitleLanguage, ')
          ..write('subtitlesEnabled: $subtitlesEnabled, ')
          ..write('autoPlayNext: $autoPlayNext, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverRevision: $serverRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    preferredAudioLanguage,
    preferredSubtitleLanguage,
    subtitlesEnabled,
    autoPlayNext,
    updatedAt,
    serverRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfilePreference &&
          other.profileId == this.profileId &&
          other.preferredAudioLanguage == this.preferredAudioLanguage &&
          other.preferredSubtitleLanguage == this.preferredSubtitleLanguage &&
          other.subtitlesEnabled == this.subtitlesEnabled &&
          other.autoPlayNext == this.autoPlayNext &&
          other.updatedAt == this.updatedAt &&
          other.serverRevision == this.serverRevision);
}

class LocalProfilePreferencesCompanion
    extends UpdateCompanion<LocalProfilePreference> {
  final Value<String> profileId;
  final Value<String?> preferredAudioLanguage;
  final Value<String?> preferredSubtitleLanguage;
  final Value<bool> subtitlesEnabled;
  final Value<bool> autoPlayNext;
  final Value<DateTime> updatedAt;
  final Value<int> serverRevision;
  final Value<int> rowid;
  const LocalProfilePreferencesCompanion({
    this.profileId = const Value.absent(),
    this.preferredAudioLanguage = const Value.absent(),
    this.preferredSubtitleLanguage = const Value.absent(),
    this.subtitlesEnabled = const Value.absent(),
    this.autoPlayNext = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfilePreferencesCompanion.insert({
    required String profileId,
    this.preferredAudioLanguage = const Value.absent(),
    this.preferredSubtitleLanguage = const Value.absent(),
    this.subtitlesEnabled = const Value.absent(),
    this.autoPlayNext = const Value.absent(),
    required DateTime updatedAt,
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       updatedAt = Value(updatedAt);
  static Insertable<LocalProfilePreference> custom({
    Expression<String>? profileId,
    Expression<String>? preferredAudioLanguage,
    Expression<String>? preferredSubtitleLanguage,
    Expression<bool>? subtitlesEnabled,
    Expression<bool>? autoPlayNext,
    Expression<DateTime>? updatedAt,
    Expression<int>? serverRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (preferredAudioLanguage != null)
        'preferred_audio_language': preferredAudioLanguage,
      if (preferredSubtitleLanguage != null)
        'preferred_subtitle_language': preferredSubtitleLanguage,
      if (subtitlesEnabled != null) 'subtitles_enabled': subtitlesEnabled,
      if (autoPlayNext != null) 'auto_play_next': autoPlayNext,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfilePreferencesCompanion copyWith({
    Value<String>? profileId,
    Value<String?>? preferredAudioLanguage,
    Value<String?>? preferredSubtitleLanguage,
    Value<bool>? subtitlesEnabled,
    Value<bool>? autoPlayNext,
    Value<DateTime>? updatedAt,
    Value<int>? serverRevision,
    Value<int>? rowid,
  }) {
    return LocalProfilePreferencesCompanion(
      profileId: profileId ?? this.profileId,
      preferredAudioLanguage:
          preferredAudioLanguage ?? this.preferredAudioLanguage,
      preferredSubtitleLanguage:
          preferredSubtitleLanguage ?? this.preferredSubtitleLanguage,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      updatedAt: updatedAt ?? this.updatedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (preferredAudioLanguage.present) {
      map['preferred_audio_language'] = Variable<String>(
        preferredAudioLanguage.value,
      );
    }
    if (preferredSubtitleLanguage.present) {
      map['preferred_subtitle_language'] = Variable<String>(
        preferredSubtitleLanguage.value,
      );
    }
    if (subtitlesEnabled.present) {
      map['subtitles_enabled'] = Variable<bool>(subtitlesEnabled.value);
    }
    if (autoPlayNext.present) {
      map['auto_play_next'] = Variable<bool>(autoPlayNext.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilePreferencesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('preferredAudioLanguage: $preferredAudioLanguage, ')
          ..write('preferredSubtitleLanguage: $preferredSubtitleLanguage, ')
          ..write('subtitlesEnabled: $subtitlesEnabled, ')
          ..write('autoPlayNext: $autoPlayNext, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProfileSyncQueueTable extends LocalProfileSyncQueue
    with TableInfo<$LocalProfileSyncQueueTable, LocalProfileSyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfileSyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientSequenceMeta = const VerificationMeta(
    'clientSequence',
  );
  @override
  late final GeneratedColumn<int> clientSequence = GeneratedColumn<int>(
    'client_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playbackSessionIdMeta = const VerificationMeta(
    'playbackSessionId',
  );
  @override
  late final GeneratedColumn<String> playbackSessionId =
      GeneratedColumn<String>(
        'playback_session_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentKeyMeta = const VerificationMeta(
    'contentKey',
  );
  @override
  late final GeneratedColumn<String> contentKey = GeneratedColumn<String>(
    'content_key',
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
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _clientTimestampMeta = const VerificationMeta(
    'clientTimestamp',
  );
  @override
  late final GeneratedColumn<DateTime> clientTimestamp =
      GeneratedColumn<DateTime>(
        'client_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    profileId,
    deviceId,
    clientSequence,
    playbackSessionId,
    operationType,
    contentKey,
    titleId,
    episodeId,
    payload,
    clientTimestamp,
    status,
    retryCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profile_sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfileSyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('client_sequence')) {
      context.handle(
        _clientSequenceMeta,
        clientSequence.isAcceptableOrUnknown(
          data['client_sequence']!,
          _clientSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientSequenceMeta);
    }
    if (data.containsKey('playback_session_id')) {
      context.handle(
        _playbackSessionIdMeta,
        playbackSessionId.isAcceptableOrUnknown(
          data['playback_session_id']!,
          _playbackSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('content_key')) {
      context.handle(
        _contentKeyMeta,
        contentKey.isAcceptableOrUnknown(data['content_key']!, _contentKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contentKeyMeta);
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
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('client_timestamp')) {
      context.handle(
        _clientTimestampMeta,
        clientTimestamp.isAcceptableOrUnknown(
          data['client_timestamp']!,
          _clientTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientTimestampMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  LocalProfileSyncQueueData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfileSyncQueueData(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      clientSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_sequence'],
      )!,
      playbackSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playback_session_id'],
      ),
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      contentKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_key'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      ),
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      clientTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_timestamp'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalProfileSyncQueueTable createAlias(String alias) {
    return $LocalProfileSyncQueueTable(attachedDatabase, alias);
  }
}

class LocalProfileSyncQueueData extends DataClass
    implements Insertable<LocalProfileSyncQueueData> {
  final String operationId;
  final String profileId;
  final String deviceId;
  final int clientSequence;
  final String? playbackSessionId;
  final String operationType;
  final String contentKey;
  final String? titleId;
  final String? episodeId;
  final String payload;
  final DateTime clientTimestamp;
  final String status;
  final int retryCount;
  final DateTime createdAt;
  const LocalProfileSyncQueueData({
    required this.operationId,
    required this.profileId,
    required this.deviceId,
    required this.clientSequence,
    this.playbackSessionId,
    required this.operationType,
    required this.contentKey,
    this.titleId,
    this.episodeId,
    required this.payload,
    required this.clientTimestamp,
    required this.status,
    required this.retryCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['profile_id'] = Variable<String>(profileId);
    map['device_id'] = Variable<String>(deviceId);
    map['client_sequence'] = Variable<int>(clientSequence);
    if (!nullToAbsent || playbackSessionId != null) {
      map['playback_session_id'] = Variable<String>(playbackSessionId);
    }
    map['operation_type'] = Variable<String>(operationType);
    map['content_key'] = Variable<String>(contentKey);
    if (!nullToAbsent || titleId != null) {
      map['title_id'] = Variable<String>(titleId);
    }
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<String>(episodeId);
    }
    map['payload'] = Variable<String>(payload);
    map['client_timestamp'] = Variable<DateTime>(clientTimestamp);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalProfileSyncQueueCompanion toCompanion(bool nullToAbsent) {
    return LocalProfileSyncQueueCompanion(
      operationId: Value(operationId),
      profileId: Value(profileId),
      deviceId: Value(deviceId),
      clientSequence: Value(clientSequence),
      playbackSessionId: playbackSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(playbackSessionId),
      operationType: Value(operationType),
      contentKey: Value(contentKey),
      titleId: titleId == null && nullToAbsent
          ? const Value.absent()
          : Value(titleId),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      payload: Value(payload),
      clientTimestamp: Value(clientTimestamp),
      status: Value(status),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
    );
  }

  factory LocalProfileSyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfileSyncQueueData(
      operationId: serializer.fromJson<String>(json['operationId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      clientSequence: serializer.fromJson<int>(json['clientSequence']),
      playbackSessionId: serializer.fromJson<String?>(
        json['playbackSessionId'],
      ),
      operationType: serializer.fromJson<String>(json['operationType']),
      contentKey: serializer.fromJson<String>(json['contentKey']),
      titleId: serializer.fromJson<String?>(json['titleId']),
      episodeId: serializer.fromJson<String?>(json['episodeId']),
      payload: serializer.fromJson<String>(json['payload']),
      clientTimestamp: serializer.fromJson<DateTime>(json['clientTimestamp']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'profileId': serializer.toJson<String>(profileId),
      'deviceId': serializer.toJson<String>(deviceId),
      'clientSequence': serializer.toJson<int>(clientSequence),
      'playbackSessionId': serializer.toJson<String?>(playbackSessionId),
      'operationType': serializer.toJson<String>(operationType),
      'contentKey': serializer.toJson<String>(contentKey),
      'titleId': serializer.toJson<String?>(titleId),
      'episodeId': serializer.toJson<String?>(episodeId),
      'payload': serializer.toJson<String>(payload),
      'clientTimestamp': serializer.toJson<DateTime>(clientTimestamp),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalProfileSyncQueueData copyWith({
    String? operationId,
    String? profileId,
    String? deviceId,
    int? clientSequence,
    Value<String?> playbackSessionId = const Value.absent(),
    String? operationType,
    String? contentKey,
    Value<String?> titleId = const Value.absent(),
    Value<String?> episodeId = const Value.absent(),
    String? payload,
    DateTime? clientTimestamp,
    String? status,
    int? retryCount,
    DateTime? createdAt,
  }) => LocalProfileSyncQueueData(
    operationId: operationId ?? this.operationId,
    profileId: profileId ?? this.profileId,
    deviceId: deviceId ?? this.deviceId,
    clientSequence: clientSequence ?? this.clientSequence,
    playbackSessionId: playbackSessionId.present
        ? playbackSessionId.value
        : this.playbackSessionId,
    operationType: operationType ?? this.operationType,
    contentKey: contentKey ?? this.contentKey,
    titleId: titleId.present ? titleId.value : this.titleId,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    payload: payload ?? this.payload,
    clientTimestamp: clientTimestamp ?? this.clientTimestamp,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalProfileSyncQueueData copyWithCompanion(
    LocalProfileSyncQueueCompanion data,
  ) {
    return LocalProfileSyncQueueData(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      clientSequence: data.clientSequence.present
          ? data.clientSequence.value
          : this.clientSequence,
      playbackSessionId: data.playbackSessionId.present
          ? data.playbackSessionId.value
          : this.playbackSessionId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      contentKey: data.contentKey.present
          ? data.contentKey.value
          : this.contentKey,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      payload: data.payload.present ? data.payload.value : this.payload,
      clientTimestamp: data.clientTimestamp.present
          ? data.clientTimestamp.value
          : this.clientTimestamp,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileSyncQueueData(')
          ..write('operationId: $operationId, ')
          ..write('profileId: $profileId, ')
          ..write('deviceId: $deviceId, ')
          ..write('clientSequence: $clientSequence, ')
          ..write('playbackSessionId: $playbackSessionId, ')
          ..write('operationType: $operationType, ')
          ..write('contentKey: $contentKey, ')
          ..write('titleId: $titleId, ')
          ..write('episodeId: $episodeId, ')
          ..write('payload: $payload, ')
          ..write('clientTimestamp: $clientTimestamp, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    profileId,
    deviceId,
    clientSequence,
    playbackSessionId,
    operationType,
    contentKey,
    titleId,
    episodeId,
    payload,
    clientTimestamp,
    status,
    retryCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfileSyncQueueData &&
          other.operationId == this.operationId &&
          other.profileId == this.profileId &&
          other.deviceId == this.deviceId &&
          other.clientSequence == this.clientSequence &&
          other.playbackSessionId == this.playbackSessionId &&
          other.operationType == this.operationType &&
          other.contentKey == this.contentKey &&
          other.titleId == this.titleId &&
          other.episodeId == this.episodeId &&
          other.payload == this.payload &&
          other.clientTimestamp == this.clientTimestamp &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt);
}

class LocalProfileSyncQueueCompanion
    extends UpdateCompanion<LocalProfileSyncQueueData> {
  final Value<String> operationId;
  final Value<String> profileId;
  final Value<String> deviceId;
  final Value<int> clientSequence;
  final Value<String?> playbackSessionId;
  final Value<String> operationType;
  final Value<String> contentKey;
  final Value<String?> titleId;
  final Value<String?> episodeId;
  final Value<String> payload;
  final Value<DateTime> clientTimestamp;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalProfileSyncQueueCompanion({
    this.operationId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.clientSequence = const Value.absent(),
    this.playbackSessionId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.contentKey = const Value.absent(),
    this.titleId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.payload = const Value.absent(),
    this.clientTimestamp = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfileSyncQueueCompanion.insert({
    required String operationId,
    required String profileId,
    required String deviceId,
    required int clientSequence,
    this.playbackSessionId = const Value.absent(),
    required String operationType,
    required String contentKey,
    this.titleId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.payload = const Value.absent(),
    required DateTime clientTimestamp,
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       profileId = Value(profileId),
       deviceId = Value(deviceId),
       clientSequence = Value(clientSequence),
       operationType = Value(operationType),
       contentKey = Value(contentKey),
       clientTimestamp = Value(clientTimestamp),
       createdAt = Value(createdAt);
  static Insertable<LocalProfileSyncQueueData> custom({
    Expression<String>? operationId,
    Expression<String>? profileId,
    Expression<String>? deviceId,
    Expression<int>? clientSequence,
    Expression<String>? playbackSessionId,
    Expression<String>? operationType,
    Expression<String>? contentKey,
    Expression<String>? titleId,
    Expression<String>? episodeId,
    Expression<String>? payload,
    Expression<DateTime>? clientTimestamp,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (profileId != null) 'profile_id': profileId,
      if (deviceId != null) 'device_id': deviceId,
      if (clientSequence != null) 'client_sequence': clientSequence,
      if (playbackSessionId != null) 'playback_session_id': playbackSessionId,
      if (operationType != null) 'operation_type': operationType,
      if (contentKey != null) 'content_key': contentKey,
      if (titleId != null) 'title_id': titleId,
      if (episodeId != null) 'episode_id': episodeId,
      if (payload != null) 'payload': payload,
      if (clientTimestamp != null) 'client_timestamp': clientTimestamp,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfileSyncQueueCompanion copyWith({
    Value<String>? operationId,
    Value<String>? profileId,
    Value<String>? deviceId,
    Value<int>? clientSequence,
    Value<String?>? playbackSessionId,
    Value<String>? operationType,
    Value<String>? contentKey,
    Value<String?>? titleId,
    Value<String?>? episodeId,
    Value<String>? payload,
    Value<DateTime>? clientTimestamp,
    Value<String>? status,
    Value<int>? retryCount,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalProfileSyncQueueCompanion(
      operationId: operationId ?? this.operationId,
      profileId: profileId ?? this.profileId,
      deviceId: deviceId ?? this.deviceId,
      clientSequence: clientSequence ?? this.clientSequence,
      playbackSessionId: playbackSessionId ?? this.playbackSessionId,
      operationType: operationType ?? this.operationType,
      contentKey: contentKey ?? this.contentKey,
      titleId: titleId ?? this.titleId,
      episodeId: episodeId ?? this.episodeId,
      payload: payload ?? this.payload,
      clientTimestamp: clientTimestamp ?? this.clientTimestamp,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (clientSequence.present) {
      map['client_sequence'] = Variable<int>(clientSequence.value);
    }
    if (playbackSessionId.present) {
      map['playback_session_id'] = Variable<String>(playbackSessionId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (contentKey.present) {
      map['content_key'] = Variable<String>(contentKey.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (clientTimestamp.present) {
      map['client_timestamp'] = Variable<DateTime>(clientTimestamp.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileSyncQueueCompanion(')
          ..write('operationId: $operationId, ')
          ..write('profileId: $profileId, ')
          ..write('deviceId: $deviceId, ')
          ..write('clientSequence: $clientSequence, ')
          ..write('playbackSessionId: $playbackSessionId, ')
          ..write('operationType: $operationType, ')
          ..write('contentKey: $contentKey, ')
          ..write('titleId: $titleId, ')
          ..write('episodeId: $episodeId, ')
          ..write('payload: $payload, ')
          ..write('clientTimestamp: $clientTimestamp, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProfileSyncCheckpointTable extends LocalProfileSyncCheckpoint
    with
        TableInfo<
          $LocalProfileSyncCheckpointTable,
          LocalProfileSyncCheckpointData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfileSyncCheckpointTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latestServerRevisionMeta =
      const VerificationMeta('latestServerRevision');
  @override
  late final GeneratedColumn<int> latestServerRevision = GeneratedColumn<int>(
    'latest_server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSuccessfulSequenceMeta =
      const VerificationMeta('lastSuccessfulSequence');
  @override
  late final GeneratedColumn<int> lastSuccessfulSequence = GeneratedColumn<int>(
    'last_successful_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    latestServerRevision,
    lastSyncedAt,
    lastSuccessfulSequence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profile_sync_checkpoint';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfileSyncCheckpointData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('latest_server_revision')) {
      context.handle(
        _latestServerRevisionMeta,
        latestServerRevision.isAcceptableOrUnknown(
          data['latest_server_revision']!,
          _latestServerRevisionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_successful_sequence')) {
      context.handle(
        _lastSuccessfulSequenceMeta,
        lastSuccessfulSequence.isAcceptableOrUnknown(
          data['last_successful_sequence']!,
          _lastSuccessfulSequenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId};
  @override
  LocalProfileSyncCheckpointData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfileSyncCheckpointData(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      latestServerRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_server_revision'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      lastSuccessfulSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_successful_sequence'],
      )!,
    );
  }

  @override
  $LocalProfileSyncCheckpointTable createAlias(String alias) {
    return $LocalProfileSyncCheckpointTable(attachedDatabase, alias);
  }
}

class LocalProfileSyncCheckpointData extends DataClass
    implements Insertable<LocalProfileSyncCheckpointData> {
  final String profileId;
  final int latestServerRevision;
  final DateTime? lastSyncedAt;
  final int lastSuccessfulSequence;
  const LocalProfileSyncCheckpointData({
    required this.profileId,
    required this.latestServerRevision,
    this.lastSyncedAt,
    required this.lastSuccessfulSequence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['latest_server_revision'] = Variable<int>(latestServerRevision);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['last_successful_sequence'] = Variable<int>(lastSuccessfulSequence);
    return map;
  }

  LocalProfileSyncCheckpointCompanion toCompanion(bool nullToAbsent) {
    return LocalProfileSyncCheckpointCompanion(
      profileId: Value(profileId),
      latestServerRevision: Value(latestServerRevision),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      lastSuccessfulSequence: Value(lastSuccessfulSequence),
    );
  }

  factory LocalProfileSyncCheckpointData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfileSyncCheckpointData(
      profileId: serializer.fromJson<String>(json['profileId']),
      latestServerRevision: serializer.fromJson<int>(
        json['latestServerRevision'],
      ),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      lastSuccessfulSequence: serializer.fromJson<int>(
        json['lastSuccessfulSequence'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'latestServerRevision': serializer.toJson<int>(latestServerRevision),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'lastSuccessfulSequence': serializer.toJson<int>(lastSuccessfulSequence),
    };
  }

  LocalProfileSyncCheckpointData copyWith({
    String? profileId,
    int? latestServerRevision,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    int? lastSuccessfulSequence,
  }) => LocalProfileSyncCheckpointData(
    profileId: profileId ?? this.profileId,
    latestServerRevision: latestServerRevision ?? this.latestServerRevision,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    lastSuccessfulSequence:
        lastSuccessfulSequence ?? this.lastSuccessfulSequence,
  );
  LocalProfileSyncCheckpointData copyWithCompanion(
    LocalProfileSyncCheckpointCompanion data,
  ) {
    return LocalProfileSyncCheckpointData(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      latestServerRevision: data.latestServerRevision.present
          ? data.latestServerRevision.value
          : this.latestServerRevision,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      lastSuccessfulSequence: data.lastSuccessfulSequence.present
          ? data.lastSuccessfulSequence.value
          : this.lastSuccessfulSequence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileSyncCheckpointData(')
          ..write('profileId: $profileId, ')
          ..write('latestServerRevision: $latestServerRevision, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastSuccessfulSequence: $lastSuccessfulSequence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    latestServerRevision,
    lastSyncedAt,
    lastSuccessfulSequence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfileSyncCheckpointData &&
          other.profileId == this.profileId &&
          other.latestServerRevision == this.latestServerRevision &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.lastSuccessfulSequence == this.lastSuccessfulSequence);
}

class LocalProfileSyncCheckpointCompanion
    extends UpdateCompanion<LocalProfileSyncCheckpointData> {
  final Value<String> profileId;
  final Value<int> latestServerRevision;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> lastSuccessfulSequence;
  final Value<int> rowid;
  const LocalProfileSyncCheckpointCompanion({
    this.profileId = const Value.absent(),
    this.latestServerRevision = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.lastSuccessfulSequence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfileSyncCheckpointCompanion.insert({
    required String profileId,
    this.latestServerRevision = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.lastSuccessfulSequence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId);
  static Insertable<LocalProfileSyncCheckpointData> custom({
    Expression<String>? profileId,
    Expression<int>? latestServerRevision,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? lastSuccessfulSequence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (latestServerRevision != null)
        'latest_server_revision': latestServerRevision,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (lastSuccessfulSequence != null)
        'last_successful_sequence': lastSuccessfulSequence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfileSyncCheckpointCompanion copyWith({
    Value<String>? profileId,
    Value<int>? latestServerRevision,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? lastSuccessfulSequence,
    Value<int>? rowid,
  }) {
    return LocalProfileSyncCheckpointCompanion(
      profileId: profileId ?? this.profileId,
      latestServerRevision: latestServerRevision ?? this.latestServerRevision,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastSuccessfulSequence:
          lastSuccessfulSequence ?? this.lastSuccessfulSequence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (latestServerRevision.present) {
      map['latest_server_revision'] = Variable<int>(latestServerRevision.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (lastSuccessfulSequence.present) {
      map['last_successful_sequence'] = Variable<int>(
        lastSuccessfulSequence.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileSyncCheckpointCompanion(')
          ..write('profileId: $profileId, ')
          ..write('latestServerRevision: $latestServerRevision, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('lastSuccessfulSequence: $lastSuccessfulSequence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalGuestImportAuditTable extends LocalGuestImportAudit
    with TableInfo<$LocalGuestImportAuditTable, LocalGuestImportAuditData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalGuestImportAuditTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetProfileIdMeta = const VerificationMeta(
    'targetProfileId',
  );
  @override
  late final GeneratedColumn<String> targetProfileId = GeneratedColumn<String>(
    'target_profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importBatchIdMeta = const VerificationMeta(
    'importBatchId',
  );
  @override
  late final GeneratedColumn<String> importBatchId = GeneratedColumn<String>(
    'import_batch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favoritesCountMeta = const VerificationMeta(
    'favoritesCount',
  );
  @override
  late final GeneratedColumn<int> favoritesCount = GeneratedColumn<int>(
    'favorites_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressCountMeta = const VerificationMeta(
    'progressCount',
  );
  @override
  late final GeneratedColumn<int> progressCount = GeneratedColumn<int>(
    'progress_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _historyCountMeta = const VerificationMeta(
    'historyCount',
  );
  @override
  late final GeneratedColumn<int> historyCount = GeneratedColumn<int>(
    'history_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
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
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetProfileId,
    importBatchId,
    status,
    favoritesCount,
    progressCount,
    historyCount,
    errorMessage,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_guest_import_audit';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalGuestImportAuditData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('target_profile_id')) {
      context.handle(
        _targetProfileIdMeta,
        targetProfileId.isAcceptableOrUnknown(
          data['target_profile_id']!,
          _targetProfileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetProfileIdMeta);
    }
    if (data.containsKey('import_batch_id')) {
      context.handle(
        _importBatchIdMeta,
        importBatchId.isAcceptableOrUnknown(
          data['import_batch_id']!,
          _importBatchIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importBatchIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('favorites_count')) {
      context.handle(
        _favoritesCountMeta,
        favoritesCount.isAcceptableOrUnknown(
          data['favorites_count']!,
          _favoritesCountMeta,
        ),
      );
    }
    if (data.containsKey('progress_count')) {
      context.handle(
        _progressCountMeta,
        progressCount.isAcceptableOrUnknown(
          data['progress_count']!,
          _progressCountMeta,
        ),
      );
    }
    if (data.containsKey('history_count')) {
      context.handle(
        _historyCountMeta,
        historyCount.isAcceptableOrUnknown(
          data['history_count']!,
          _historyCountMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
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
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalGuestImportAuditData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalGuestImportAuditData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      targetProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_profile_id'],
      )!,
      importBatchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_batch_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      favoritesCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorites_count'],
      )!,
      progressCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress_count'],
      )!,
      historyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}history_count'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $LocalGuestImportAuditTable createAlias(String alias) {
    return $LocalGuestImportAuditTable(attachedDatabase, alias);
  }
}

class LocalGuestImportAuditData extends DataClass
    implements Insertable<LocalGuestImportAuditData> {
  final String id;
  final String targetProfileId;
  final String importBatchId;
  final String status;
  final int favoritesCount;
  final int progressCount;
  final int historyCount;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  const LocalGuestImportAuditData({
    required this.id,
    required this.targetProfileId,
    required this.importBatchId,
    required this.status,
    required this.favoritesCount,
    required this.progressCount,
    required this.historyCount,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['target_profile_id'] = Variable<String>(targetProfileId);
    map['import_batch_id'] = Variable<String>(importBatchId);
    map['status'] = Variable<String>(status);
    map['favorites_count'] = Variable<int>(favoritesCount);
    map['progress_count'] = Variable<int>(progressCount);
    map['history_count'] = Variable<int>(historyCount);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  LocalGuestImportAuditCompanion toCompanion(bool nullToAbsent) {
    return LocalGuestImportAuditCompanion(
      id: Value(id),
      targetProfileId: Value(targetProfileId),
      importBatchId: Value(importBatchId),
      status: Value(status),
      favoritesCount: Value(favoritesCount),
      progressCount: Value(progressCount),
      historyCount: Value(historyCount),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory LocalGuestImportAuditData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalGuestImportAuditData(
      id: serializer.fromJson<String>(json['id']),
      targetProfileId: serializer.fromJson<String>(json['targetProfileId']),
      importBatchId: serializer.fromJson<String>(json['importBatchId']),
      status: serializer.fromJson<String>(json['status']),
      favoritesCount: serializer.fromJson<int>(json['favoritesCount']),
      progressCount: serializer.fromJson<int>(json['progressCount']),
      historyCount: serializer.fromJson<int>(json['historyCount']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'targetProfileId': serializer.toJson<String>(targetProfileId),
      'importBatchId': serializer.toJson<String>(importBatchId),
      'status': serializer.toJson<String>(status),
      'favoritesCount': serializer.toJson<int>(favoritesCount),
      'progressCount': serializer.toJson<int>(progressCount),
      'historyCount': serializer.toJson<int>(historyCount),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  LocalGuestImportAuditData copyWith({
    String? id,
    String? targetProfileId,
    String? importBatchId,
    String? status,
    int? favoritesCount,
    int? progressCount,
    int? historyCount,
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => LocalGuestImportAuditData(
    id: id ?? this.id,
    targetProfileId: targetProfileId ?? this.targetProfileId,
    importBatchId: importBatchId ?? this.importBatchId,
    status: status ?? this.status,
    favoritesCount: favoritesCount ?? this.favoritesCount,
    progressCount: progressCount ?? this.progressCount,
    historyCount: historyCount ?? this.historyCount,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  LocalGuestImportAuditData copyWithCompanion(
    LocalGuestImportAuditCompanion data,
  ) {
    return LocalGuestImportAuditData(
      id: data.id.present ? data.id.value : this.id,
      targetProfileId: data.targetProfileId.present
          ? data.targetProfileId.value
          : this.targetProfileId,
      importBatchId: data.importBatchId.present
          ? data.importBatchId.value
          : this.importBatchId,
      status: data.status.present ? data.status.value : this.status,
      favoritesCount: data.favoritesCount.present
          ? data.favoritesCount.value
          : this.favoritesCount,
      progressCount: data.progressCount.present
          ? data.progressCount.value
          : this.progressCount,
      historyCount: data.historyCount.present
          ? data.historyCount.value
          : this.historyCount,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalGuestImportAuditData(')
          ..write('id: $id, ')
          ..write('targetProfileId: $targetProfileId, ')
          ..write('importBatchId: $importBatchId, ')
          ..write('status: $status, ')
          ..write('favoritesCount: $favoritesCount, ')
          ..write('progressCount: $progressCount, ')
          ..write('historyCount: $historyCount, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    targetProfileId,
    importBatchId,
    status,
    favoritesCount,
    progressCount,
    historyCount,
    errorMessage,
    createdAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalGuestImportAuditData &&
          other.id == this.id &&
          other.targetProfileId == this.targetProfileId &&
          other.importBatchId == this.importBatchId &&
          other.status == this.status &&
          other.favoritesCount == this.favoritesCount &&
          other.progressCount == this.progressCount &&
          other.historyCount == this.historyCount &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class LocalGuestImportAuditCompanion
    extends UpdateCompanion<LocalGuestImportAuditData> {
  final Value<String> id;
  final Value<String> targetProfileId;
  final Value<String> importBatchId;
  final Value<String> status;
  final Value<int> favoritesCount;
  final Value<int> progressCount;
  final Value<int> historyCount;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const LocalGuestImportAuditCompanion({
    this.id = const Value.absent(),
    this.targetProfileId = const Value.absent(),
    this.importBatchId = const Value.absent(),
    this.status = const Value.absent(),
    this.favoritesCount = const Value.absent(),
    this.progressCount = const Value.absent(),
    this.historyCount = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalGuestImportAuditCompanion.insert({
    required String id,
    required String targetProfileId,
    required String importBatchId,
    required String status,
    this.favoritesCount = const Value.absent(),
    this.progressCount = const Value.absent(),
    this.historyCount = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       targetProfileId = Value(targetProfileId),
       importBatchId = Value(importBatchId),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<LocalGuestImportAuditData> custom({
    Expression<String>? id,
    Expression<String>? targetProfileId,
    Expression<String>? importBatchId,
    Expression<String>? status,
    Expression<int>? favoritesCount,
    Expression<int>? progressCount,
    Expression<int>? historyCount,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetProfileId != null) 'target_profile_id': targetProfileId,
      if (importBatchId != null) 'import_batch_id': importBatchId,
      if (status != null) 'status': status,
      if (favoritesCount != null) 'favorites_count': favoritesCount,
      if (progressCount != null) 'progress_count': progressCount,
      if (historyCount != null) 'history_count': historyCount,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalGuestImportAuditCompanion copyWith({
    Value<String>? id,
    Value<String>? targetProfileId,
    Value<String>? importBatchId,
    Value<String>? status,
    Value<int>? favoritesCount,
    Value<int>? progressCount,
    Value<int>? historyCount,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return LocalGuestImportAuditCompanion(
      id: id ?? this.id,
      targetProfileId: targetProfileId ?? this.targetProfileId,
      importBatchId: importBatchId ?? this.importBatchId,
      status: status ?? this.status,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      progressCount: progressCount ?? this.progressCount,
      historyCount: historyCount ?? this.historyCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (targetProfileId.present) {
      map['target_profile_id'] = Variable<String>(targetProfileId.value);
    }
    if (importBatchId.present) {
      map['import_batch_id'] = Variable<String>(importBatchId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (favoritesCount.present) {
      map['favorites_count'] = Variable<int>(favoritesCount.value);
    }
    if (progressCount.present) {
      map['progress_count'] = Variable<int>(progressCount.value);
    }
    if (historyCount.present) {
      map['history_count'] = Variable<int>(historyCount.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalGuestImportAuditCompanion(')
          ..write('id: $id, ')
          ..write('targetProfileId: $targetProfileId, ')
          ..write('importBatchId: $importBatchId, ')
          ..write('status: $status, ')
          ..write('favoritesCount: $favoritesCount, ')
          ..write('progressCount: $progressCount, ')
          ..write('historyCount: $historyCount, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
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
  late final $LocalProfileFavoritesTable localProfileFavorites =
      $LocalProfileFavoritesTable(this);
  late final $LocalProfilePlaybackProgressTable localProfilePlaybackProgress =
      $LocalProfilePlaybackProgressTable(this);
  late final $LocalProfileHistoryTable localProfileHistory =
      $LocalProfileHistoryTable(this);
  late final $LocalProfilePreferencesTable localProfilePreferences =
      $LocalProfilePreferencesTable(this);
  late final $LocalProfileSyncQueueTable localProfileSyncQueue =
      $LocalProfileSyncQueueTable(this);
  late final $LocalProfileSyncCheckpointTable localProfileSyncCheckpoint =
      $LocalProfileSyncCheckpointTable(this);
  late final $LocalGuestImportAuditTable localGuestImportAudit =
      $LocalGuestImportAuditTable(this);
  late final CatalogDao catalogDao = CatalogDao(this as CatalogDatabase);
  late final UserDataDao userDataDao = UserDataDao(this as CatalogDatabase);
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
    localProfileFavorites,
    localProfilePlaybackProgress,
    localProfileHistory,
    localProfilePreferences,
    localProfileSyncQueue,
    localProfileSyncCheckpoint,
    localGuestImportAudit,
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
      Value<String> healthStatus,
      Value<String?> healthLastError,
      Value<int?> healthHttpCode,
      Value<int> healthConsecutiveFailures,
      Value<DateTime?> healthFirstFailureAt,
      Value<DateTime?> healthLastSuccessAt,
      Value<DateTime?> healthLastCheck,
      Value<String?> healthLastCheckRunId,
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
      Value<String> healthStatus,
      Value<String?> healthLastError,
      Value<int?> healthHttpCode,
      Value<int> healthConsecutiveFailures,
      Value<DateTime?> healthFirstFailureAt,
      Value<DateTime?> healthLastSuccessAt,
      Value<DateTime?> healthLastCheck,
      Value<String?> healthLastCheckRunId,
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

  ColumnFilters<String> get healthStatus => $composableBuilder(
    column: $table.healthStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get healthLastError => $composableBuilder(
    column: $table.healthLastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get healthHttpCode => $composableBuilder(
    column: $table.healthHttpCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get healthConsecutiveFailures => $composableBuilder(
    column: $table.healthConsecutiveFailures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get healthFirstFailureAt => $composableBuilder(
    column: $table.healthFirstFailureAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get healthLastSuccessAt => $composableBuilder(
    column: $table.healthLastSuccessAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get healthLastCheck => $composableBuilder(
    column: $table.healthLastCheck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get healthLastCheckRunId => $composableBuilder(
    column: $table.healthLastCheckRunId,
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

  ColumnOrderings<String> get healthStatus => $composableBuilder(
    column: $table.healthStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get healthLastError => $composableBuilder(
    column: $table.healthLastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get healthHttpCode => $composableBuilder(
    column: $table.healthHttpCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get healthConsecutiveFailures => $composableBuilder(
    column: $table.healthConsecutiveFailures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get healthFirstFailureAt => $composableBuilder(
    column: $table.healthFirstFailureAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get healthLastSuccessAt => $composableBuilder(
    column: $table.healthLastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get healthLastCheck => $composableBuilder(
    column: $table.healthLastCheck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get healthLastCheckRunId => $composableBuilder(
    column: $table.healthLastCheckRunId,
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

  GeneratedColumn<String> get healthStatus => $composableBuilder(
    column: $table.healthStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get healthLastError => $composableBuilder(
    column: $table.healthLastError,
    builder: (column) => column,
  );

  GeneratedColumn<int> get healthHttpCode => $composableBuilder(
    column: $table.healthHttpCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get healthConsecutiveFailures => $composableBuilder(
    column: $table.healthConsecutiveFailures,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get healthFirstFailureAt => $composableBuilder(
    column: $table.healthFirstFailureAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get healthLastSuccessAt => $composableBuilder(
    column: $table.healthLastSuccessAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get healthLastCheck => $composableBuilder(
    column: $table.healthLastCheck,
    builder: (column) => column,
  );

  GeneratedColumn<String> get healthLastCheckRunId => $composableBuilder(
    column: $table.healthLastCheckRunId,
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
                Value<String> healthStatus = const Value.absent(),
                Value<String?> healthLastError = const Value.absent(),
                Value<int?> healthHttpCode = const Value.absent(),
                Value<int> healthConsecutiveFailures = const Value.absent(),
                Value<DateTime?> healthFirstFailureAt = const Value.absent(),
                Value<DateTime?> healthLastSuccessAt = const Value.absent(),
                Value<DateTime?> healthLastCheck = const Value.absent(),
                Value<String?> healthLastCheckRunId = const Value.absent(),
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
                healthStatus: healthStatus,
                healthLastError: healthLastError,
                healthHttpCode: healthHttpCode,
                healthConsecutiveFailures: healthConsecutiveFailures,
                healthFirstFailureAt: healthFirstFailureAt,
                healthLastSuccessAt: healthLastSuccessAt,
                healthLastCheck: healthLastCheck,
                healthLastCheckRunId: healthLastCheckRunId,
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
                Value<String> healthStatus = const Value.absent(),
                Value<String?> healthLastError = const Value.absent(),
                Value<int?> healthHttpCode = const Value.absent(),
                Value<int> healthConsecutiveFailures = const Value.absent(),
                Value<DateTime?> healthFirstFailureAt = const Value.absent(),
                Value<DateTime?> healthLastSuccessAt = const Value.absent(),
                Value<DateTime?> healthLastCheck = const Value.absent(),
                Value<String?> healthLastCheckRunId = const Value.absent(),
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
                healthStatus: healthStatus,
                healthLastError: healthLastError,
                healthHttpCode: healthHttpCode,
                healthConsecutiveFailures: healthConsecutiveFailures,
                healthFirstFailureAt: healthFirstFailureAt,
                healthLastSuccessAt: healthLastSuccessAt,
                healthLastCheck: healthLastCheck,
                healthLastCheckRunId: healthLastCheckRunId,
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
typedef $$LocalProfileFavoritesTableCreateCompanionBuilder =
    LocalProfileFavoritesCompanion Function({
      required String profileId,
      required String contentKey,
      Value<String?> titleId,
      Value<bool> isFavorite,
      required DateTime updatedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });
typedef $$LocalProfileFavoritesTableUpdateCompanionBuilder =
    LocalProfileFavoritesCompanion Function({
      Value<String> profileId,
      Value<String> contentKey,
      Value<String?> titleId,
      Value<bool> isFavorite,
      Value<DateTime> updatedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });

class $$LocalProfileFavoritesTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalProfileFavoritesTable> {
  $$LocalProfileFavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfileFavoritesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalProfileFavoritesTable> {
  $$LocalProfileFavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfileFavoritesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalProfileFavoritesTable> {
  $$LocalProfileFavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );
}

class $$LocalProfileFavoritesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalProfileFavoritesTable,
          LocalProfileFavorite,
          $$LocalProfileFavoritesTableFilterComposer,
          $$LocalProfileFavoritesTableOrderingComposer,
          $$LocalProfileFavoritesTableAnnotationComposer,
          $$LocalProfileFavoritesTableCreateCompanionBuilder,
          $$LocalProfileFavoritesTableUpdateCompanionBuilder,
          (
            LocalProfileFavorite,
            BaseReferences<
              _$CatalogDatabase,
              $LocalProfileFavoritesTable,
              LocalProfileFavorite
            >,
          ),
          LocalProfileFavorite,
          PrefetchHooks Function()
        > {
  $$LocalProfileFavoritesTableTableManager(
    _$CatalogDatabase db,
    $LocalProfileFavoritesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfileFavoritesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalProfileFavoritesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalProfileFavoritesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> contentKey = const Value.absent(),
                Value<String?> titleId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfileFavoritesCompanion(
                profileId: profileId,
                contentKey: contentKey,
                titleId: titleId,
                isFavorite: isFavorite,
                updatedAt: updatedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String contentKey,
                Value<String?> titleId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                required DateTime updatedAt,
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfileFavoritesCompanion.insert(
                profileId: profileId,
                contentKey: contentKey,
                titleId: titleId,
                isFavorite: isFavorite,
                updatedAt: updatedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalProfileFavoritesTable,
                    LocalProfileFavorite
                  >(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LocalProfileFavoritesTable,
                    LocalProfileFavorite
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfileFavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalProfileFavoritesTable,
      LocalProfileFavorite,
      $$LocalProfileFavoritesTableFilterComposer,
      $$LocalProfileFavoritesTableOrderingComposer,
      $$LocalProfileFavoritesTableAnnotationComposer,
      $$LocalProfileFavoritesTableCreateCompanionBuilder,
      $$LocalProfileFavoritesTableUpdateCompanionBuilder,
      (
        LocalProfileFavorite,
        BaseReferences<
          _$CatalogDatabase,
          $LocalProfileFavoritesTable,
          LocalProfileFavorite
        >,
      ),
      LocalProfileFavorite,
      PrefetchHooks Function()
    >;
typedef $$LocalProfilePlaybackProgressTableCreateCompanionBuilder =
    LocalProfilePlaybackProgressCompanion Function({
      required String profileId,
      required String contentKey,
      Value<String?> playbackSessionId,
      Value<String?> titleId,
      Value<String?> episodeId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<double> fraction,
      Value<bool> isCompleted,
      required DateTime lastWatchedAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });
typedef $$LocalProfilePlaybackProgressTableUpdateCompanionBuilder =
    LocalProfilePlaybackProgressCompanion Function({
      Value<String> profileId,
      Value<String> contentKey,
      Value<String?> playbackSessionId,
      Value<String?> titleId,
      Value<String?> episodeId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<double> fraction,
      Value<bool> isCompleted,
      Value<DateTime> lastWatchedAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });

class $$LocalProfilePlaybackProgressTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalProfilePlaybackProgressTable> {
  $$LocalProfilePlaybackProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fraction => $composableBuilder(
    column: $table.fraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfilePlaybackProgressTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalProfilePlaybackProgressTable> {
  $$LocalProfilePlaybackProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fraction => $composableBuilder(
    column: $table.fraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfilePlaybackProgressTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalProfilePlaybackProgressTable> {
  $$LocalProfilePlaybackProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fraction =>
      $composableBuilder(column: $table.fraction, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );
}

class $$LocalProfilePlaybackProgressTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalProfilePlaybackProgressTable,
          LocalProfilePlaybackProgressData,
          $$LocalProfilePlaybackProgressTableFilterComposer,
          $$LocalProfilePlaybackProgressTableOrderingComposer,
          $$LocalProfilePlaybackProgressTableAnnotationComposer,
          $$LocalProfilePlaybackProgressTableCreateCompanionBuilder,
          $$LocalProfilePlaybackProgressTableUpdateCompanionBuilder,
          (
            LocalProfilePlaybackProgressData,
            BaseReferences<
              _$CatalogDatabase,
              $LocalProfilePlaybackProgressTable,
              LocalProfilePlaybackProgressData
            >,
          ),
          LocalProfilePlaybackProgressData,
          PrefetchHooks Function()
        > {
  $$LocalProfilePlaybackProgressTableTableManager(
    _$CatalogDatabase db,
    $LocalProfilePlaybackProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfilePlaybackProgressTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalProfilePlaybackProgressTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalProfilePlaybackProgressTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> contentKey = const Value.absent(),
                Value<String?> playbackSessionId = const Value.absent(),
                Value<String?> titleId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<double> fraction = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime> lastWatchedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilePlaybackProgressCompanion(
                profileId: profileId,
                contentKey: contentKey,
                playbackSessionId: playbackSessionId,
                titleId: titleId,
                episodeId: episodeId,
                positionMs: positionMs,
                durationMs: durationMs,
                fraction: fraction,
                isCompleted: isCompleted,
                lastWatchedAt: lastWatchedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String contentKey,
                Value<String?> playbackSessionId = const Value.absent(),
                Value<String?> titleId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<double> fraction = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                required DateTime lastWatchedAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilePlaybackProgressCompanion.insert(
                profileId: profileId,
                contentKey: contentKey,
                playbackSessionId: playbackSessionId,
                titleId: titleId,
                episodeId: episodeId,
                positionMs: positionMs,
                durationMs: durationMs,
                fraction: fraction,
                isCompleted: isCompleted,
                lastWatchedAt: lastWatchedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalProfilePlaybackProgressTable,
                    LocalProfilePlaybackProgressData
                  >(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LocalProfilePlaybackProgressTable,
                    LocalProfilePlaybackProgressData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfilePlaybackProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalProfilePlaybackProgressTable,
      LocalProfilePlaybackProgressData,
      $$LocalProfilePlaybackProgressTableFilterComposer,
      $$LocalProfilePlaybackProgressTableOrderingComposer,
      $$LocalProfilePlaybackProgressTableAnnotationComposer,
      $$LocalProfilePlaybackProgressTableCreateCompanionBuilder,
      $$LocalProfilePlaybackProgressTableUpdateCompanionBuilder,
      (
        LocalProfilePlaybackProgressData,
        BaseReferences<
          _$CatalogDatabase,
          $LocalProfilePlaybackProgressTable,
          LocalProfilePlaybackProgressData
        >,
      ),
      LocalProfilePlaybackProgressData,
      PrefetchHooks Function()
    >;
typedef $$LocalProfileHistoryTableCreateCompanionBuilder =
    LocalProfileHistoryCompanion Function({
      required String id,
      required String profileId,
      required String playbackSessionId,
      required String contentKey,
      Value<String?> titleId,
      Value<String?> episodeId,
      Value<int> stoppedAtMs,
      Value<int> durationMs,
      Value<double> fraction,
      Value<bool> isCompleted,
      required DateTime watchedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });
typedef $$LocalProfileHistoryTableUpdateCompanionBuilder =
    LocalProfileHistoryCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> playbackSessionId,
      Value<String> contentKey,
      Value<String?> titleId,
      Value<String?> episodeId,
      Value<int> stoppedAtMs,
      Value<int> durationMs,
      Value<double> fraction,
      Value<bool> isCompleted,
      Value<DateTime> watchedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });

class $$LocalProfileHistoryTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalProfileHistoryTable> {
  $$LocalProfileHistoryTableFilterComposer({
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

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stoppedAtMs => $composableBuilder(
    column: $table.stoppedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fraction => $composableBuilder(
    column: $table.fraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfileHistoryTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalProfileHistoryTable> {
  $$LocalProfileHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stoppedAtMs => $composableBuilder(
    column: $table.stoppedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fraction => $composableBuilder(
    column: $table.fraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfileHistoryTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalProfileHistoryTable> {
  $$LocalProfileHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<int> get stoppedAtMs => $composableBuilder(
    column: $table.stoppedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fraction =>
      $composableBuilder(column: $table.fraction, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get watchedAt =>
      $composableBuilder(column: $table.watchedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );
}

class $$LocalProfileHistoryTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalProfileHistoryTable,
          LocalProfileHistoryData,
          $$LocalProfileHistoryTableFilterComposer,
          $$LocalProfileHistoryTableOrderingComposer,
          $$LocalProfileHistoryTableAnnotationComposer,
          $$LocalProfileHistoryTableCreateCompanionBuilder,
          $$LocalProfileHistoryTableUpdateCompanionBuilder,
          (
            LocalProfileHistoryData,
            BaseReferences<
              _$CatalogDatabase,
              $LocalProfileHistoryTable,
              LocalProfileHistoryData
            >,
          ),
          LocalProfileHistoryData,
          PrefetchHooks Function()
        > {
  $$LocalProfileHistoryTableTableManager(
    _$CatalogDatabase db,
    $LocalProfileHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfileHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProfileHistoryTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalProfileHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> playbackSessionId = const Value.absent(),
                Value<String> contentKey = const Value.absent(),
                Value<String?> titleId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<int> stoppedAtMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<double> fraction = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime> watchedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfileHistoryCompanion(
                id: id,
                profileId: profileId,
                playbackSessionId: playbackSessionId,
                contentKey: contentKey,
                titleId: titleId,
                episodeId: episodeId,
                stoppedAtMs: stoppedAtMs,
                durationMs: durationMs,
                fraction: fraction,
                isCompleted: isCompleted,
                watchedAt: watchedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String playbackSessionId,
                required String contentKey,
                Value<String?> titleId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<int> stoppedAtMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<double> fraction = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                required DateTime watchedAt,
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfileHistoryCompanion.insert(
                id: id,
                profileId: profileId,
                playbackSessionId: playbackSessionId,
                contentKey: contentKey,
                titleId: titleId,
                episodeId: episodeId,
                stoppedAtMs: stoppedAtMs,
                durationMs: durationMs,
                fraction: fraction,
                isCompleted: isCompleted,
                watchedAt: watchedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalProfileHistoryTable,
                    LocalProfileHistoryData
                  >(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LocalProfileHistoryTable,
                    LocalProfileHistoryData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfileHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalProfileHistoryTable,
      LocalProfileHistoryData,
      $$LocalProfileHistoryTableFilterComposer,
      $$LocalProfileHistoryTableOrderingComposer,
      $$LocalProfileHistoryTableAnnotationComposer,
      $$LocalProfileHistoryTableCreateCompanionBuilder,
      $$LocalProfileHistoryTableUpdateCompanionBuilder,
      (
        LocalProfileHistoryData,
        BaseReferences<
          _$CatalogDatabase,
          $LocalProfileHistoryTable,
          LocalProfileHistoryData
        >,
      ),
      LocalProfileHistoryData,
      PrefetchHooks Function()
    >;
typedef $$LocalProfilePreferencesTableCreateCompanionBuilder =
    LocalProfilePreferencesCompanion Function({
      required String profileId,
      Value<String?> preferredAudioLanguage,
      Value<String?> preferredSubtitleLanguage,
      Value<bool> subtitlesEnabled,
      Value<bool> autoPlayNext,
      required DateTime updatedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });
typedef $$LocalProfilePreferencesTableUpdateCompanionBuilder =
    LocalProfilePreferencesCompanion Function({
      Value<String> profileId,
      Value<String?> preferredAudioLanguage,
      Value<String?> preferredSubtitleLanguage,
      Value<bool> subtitlesEnabled,
      Value<bool> autoPlayNext,
      Value<DateTime> updatedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });

class $$LocalProfilePreferencesTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalProfilePreferencesTable> {
  $$LocalProfilePreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredAudioLanguage => $composableBuilder(
    column: $table.preferredAudioLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredSubtitleLanguage => $composableBuilder(
    column: $table.preferredSubtitleLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get subtitlesEnabled => $composableBuilder(
    column: $table.subtitlesEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoPlayNext => $composableBuilder(
    column: $table.autoPlayNext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfilePreferencesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalProfilePreferencesTable> {
  $$LocalProfilePreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredAudioLanguage => $composableBuilder(
    column: $table.preferredAudioLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredSubtitleLanguage => $composableBuilder(
    column: $table.preferredSubtitleLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get subtitlesEnabled => $composableBuilder(
    column: $table.subtitlesEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoPlayNext => $composableBuilder(
    column: $table.autoPlayNext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfilePreferencesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalProfilePreferencesTable> {
  $$LocalProfilePreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get preferredAudioLanguage => $composableBuilder(
    column: $table.preferredAudioLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredSubtitleLanguage => $composableBuilder(
    column: $table.preferredSubtitleLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get subtitlesEnabled => $composableBuilder(
    column: $table.subtitlesEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoPlayNext => $composableBuilder(
    column: $table.autoPlayNext,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );
}

class $$LocalProfilePreferencesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalProfilePreferencesTable,
          LocalProfilePreference,
          $$LocalProfilePreferencesTableFilterComposer,
          $$LocalProfilePreferencesTableOrderingComposer,
          $$LocalProfilePreferencesTableAnnotationComposer,
          $$LocalProfilePreferencesTableCreateCompanionBuilder,
          $$LocalProfilePreferencesTableUpdateCompanionBuilder,
          (
            LocalProfilePreference,
            BaseReferences<
              _$CatalogDatabase,
              $LocalProfilePreferencesTable,
              LocalProfilePreference
            >,
          ),
          LocalProfilePreference,
          PrefetchHooks Function()
        > {
  $$LocalProfilePreferencesTableTableManager(
    _$CatalogDatabase db,
    $LocalProfilePreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfilePreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalProfilePreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalProfilePreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String?> preferredAudioLanguage = const Value.absent(),
                Value<String?> preferredSubtitleLanguage = const Value.absent(),
                Value<bool> subtitlesEnabled = const Value.absent(),
                Value<bool> autoPlayNext = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilePreferencesCompanion(
                profileId: profileId,
                preferredAudioLanguage: preferredAudioLanguage,
                preferredSubtitleLanguage: preferredSubtitleLanguage,
                subtitlesEnabled: subtitlesEnabled,
                autoPlayNext: autoPlayNext,
                updatedAt: updatedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                Value<String?> preferredAudioLanguage = const Value.absent(),
                Value<String?> preferredSubtitleLanguage = const Value.absent(),
                Value<bool> subtitlesEnabled = const Value.absent(),
                Value<bool> autoPlayNext = const Value.absent(),
                required DateTime updatedAt,
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilePreferencesCompanion.insert(
                profileId: profileId,
                preferredAudioLanguage: preferredAudioLanguage,
                preferredSubtitleLanguage: preferredSubtitleLanguage,
                subtitlesEnabled: subtitlesEnabled,
                autoPlayNext: autoPlayNext,
                updatedAt: updatedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalProfilePreferencesTable,
                    LocalProfilePreference
                  >(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LocalProfilePreferencesTable,
                    LocalProfilePreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfilePreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalProfilePreferencesTable,
      LocalProfilePreference,
      $$LocalProfilePreferencesTableFilterComposer,
      $$LocalProfilePreferencesTableOrderingComposer,
      $$LocalProfilePreferencesTableAnnotationComposer,
      $$LocalProfilePreferencesTableCreateCompanionBuilder,
      $$LocalProfilePreferencesTableUpdateCompanionBuilder,
      (
        LocalProfilePreference,
        BaseReferences<
          _$CatalogDatabase,
          $LocalProfilePreferencesTable,
          LocalProfilePreference
        >,
      ),
      LocalProfilePreference,
      PrefetchHooks Function()
    >;
typedef $$LocalProfileSyncQueueTableCreateCompanionBuilder =
    LocalProfileSyncQueueCompanion Function({
      required String operationId,
      required String profileId,
      required String deviceId,
      required int clientSequence,
      Value<String?> playbackSessionId,
      required String operationType,
      required String contentKey,
      Value<String?> titleId,
      Value<String?> episodeId,
      Value<String> payload,
      required DateTime clientTimestamp,
      Value<String> status,
      Value<int> retryCount,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalProfileSyncQueueTableUpdateCompanionBuilder =
    LocalProfileSyncQueueCompanion Function({
      Value<String> operationId,
      Value<String> profileId,
      Value<String> deviceId,
      Value<int> clientSequence,
      Value<String?> playbackSessionId,
      Value<String> operationType,
      Value<String> contentKey,
      Value<String?> titleId,
      Value<String?> episodeId,
      Value<String> payload,
      Value<DateTime> clientTimestamp,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalProfileSyncQueueTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalProfileSyncQueueTable> {
  $$LocalProfileSyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clientSequence => $composableBuilder(
    column: $table.clientSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get clientTimestamp => $composableBuilder(
    column: $table.clientTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfileSyncQueueTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalProfileSyncQueueTable> {
  $$LocalProfileSyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clientSequence => $composableBuilder(
    column: $table.clientSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get clientTimestamp => $composableBuilder(
    column: $table.clientTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfileSyncQueueTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalProfileSyncQueueTable> {
  $$LocalProfileSyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get clientSequence => $composableBuilder(
    column: $table.clientSequence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playbackSessionId => $composableBuilder(
    column: $table.playbackSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentKey => $composableBuilder(
    column: $table.contentKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get clientTimestamp => $composableBuilder(
    column: $table.clientTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalProfileSyncQueueTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalProfileSyncQueueTable,
          LocalProfileSyncQueueData,
          $$LocalProfileSyncQueueTableFilterComposer,
          $$LocalProfileSyncQueueTableOrderingComposer,
          $$LocalProfileSyncQueueTableAnnotationComposer,
          $$LocalProfileSyncQueueTableCreateCompanionBuilder,
          $$LocalProfileSyncQueueTableUpdateCompanionBuilder,
          (
            LocalProfileSyncQueueData,
            BaseReferences<
              _$CatalogDatabase,
              $LocalProfileSyncQueueTable,
              LocalProfileSyncQueueData
            >,
          ),
          LocalProfileSyncQueueData,
          PrefetchHooks Function()
        > {
  $$LocalProfileSyncQueueTableTableManager(
    _$CatalogDatabase db,
    $LocalProfileSyncQueueTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfileSyncQueueTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalProfileSyncQueueTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalProfileSyncQueueTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> clientSequence = const Value.absent(),
                Value<String?> playbackSessionId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> contentKey = const Value.absent(),
                Value<String?> titleId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> clientTimestamp = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfileSyncQueueCompanion(
                operationId: operationId,
                profileId: profileId,
                deviceId: deviceId,
                clientSequence: clientSequence,
                playbackSessionId: playbackSessionId,
                operationType: operationType,
                contentKey: contentKey,
                titleId: titleId,
                episodeId: episodeId,
                payload: payload,
                clientTimestamp: clientTimestamp,
                status: status,
                retryCount: retryCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String profileId,
                required String deviceId,
                required int clientSequence,
                Value<String?> playbackSessionId = const Value.absent(),
                required String operationType,
                required String contentKey,
                Value<String?> titleId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                required DateTime clientTimestamp,
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalProfileSyncQueueCompanion.insert(
                operationId: operationId,
                profileId: profileId,
                deviceId: deviceId,
                clientSequence: clientSequence,
                playbackSessionId: playbackSessionId,
                operationType: operationType,
                contentKey: contentKey,
                titleId: titleId,
                episodeId: episodeId,
                payload: payload,
                clientTimestamp: clientTimestamp,
                status: status,
                retryCount: retryCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalProfileSyncQueueTable,
                    LocalProfileSyncQueueData
                  >(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LocalProfileSyncQueueTable,
                    LocalProfileSyncQueueData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfileSyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalProfileSyncQueueTable,
      LocalProfileSyncQueueData,
      $$LocalProfileSyncQueueTableFilterComposer,
      $$LocalProfileSyncQueueTableOrderingComposer,
      $$LocalProfileSyncQueueTableAnnotationComposer,
      $$LocalProfileSyncQueueTableCreateCompanionBuilder,
      $$LocalProfileSyncQueueTableUpdateCompanionBuilder,
      (
        LocalProfileSyncQueueData,
        BaseReferences<
          _$CatalogDatabase,
          $LocalProfileSyncQueueTable,
          LocalProfileSyncQueueData
        >,
      ),
      LocalProfileSyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$LocalProfileSyncCheckpointTableCreateCompanionBuilder =
    LocalProfileSyncCheckpointCompanion Function({
      required String profileId,
      Value<int> latestServerRevision,
      Value<DateTime?> lastSyncedAt,
      Value<int> lastSuccessfulSequence,
      Value<int> rowid,
    });
typedef $$LocalProfileSyncCheckpointTableUpdateCompanionBuilder =
    LocalProfileSyncCheckpointCompanion Function({
      Value<String> profileId,
      Value<int> latestServerRevision,
      Value<DateTime?> lastSyncedAt,
      Value<int> lastSuccessfulSequence,
      Value<int> rowid,
    });

class $$LocalProfileSyncCheckpointTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalProfileSyncCheckpointTable> {
  $$LocalProfileSyncCheckpointTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latestServerRevision => $composableBuilder(
    column: $table.latestServerRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSuccessfulSequence => $composableBuilder(
    column: $table.lastSuccessfulSequence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfileSyncCheckpointTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalProfileSyncCheckpointTable> {
  $$LocalProfileSyncCheckpointTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latestServerRevision => $composableBuilder(
    column: $table.latestServerRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSuccessfulSequence => $composableBuilder(
    column: $table.lastSuccessfulSequence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfileSyncCheckpointTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalProfileSyncCheckpointTable> {
  $$LocalProfileSyncCheckpointTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get latestServerRevision => $composableBuilder(
    column: $table.latestServerRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSuccessfulSequence => $composableBuilder(
    column: $table.lastSuccessfulSequence,
    builder: (column) => column,
  );
}

class $$LocalProfileSyncCheckpointTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalProfileSyncCheckpointTable,
          LocalProfileSyncCheckpointData,
          $$LocalProfileSyncCheckpointTableFilterComposer,
          $$LocalProfileSyncCheckpointTableOrderingComposer,
          $$LocalProfileSyncCheckpointTableAnnotationComposer,
          $$LocalProfileSyncCheckpointTableCreateCompanionBuilder,
          $$LocalProfileSyncCheckpointTableUpdateCompanionBuilder,
          (
            LocalProfileSyncCheckpointData,
            BaseReferences<
              _$CatalogDatabase,
              $LocalProfileSyncCheckpointTable,
              LocalProfileSyncCheckpointData
            >,
          ),
          LocalProfileSyncCheckpointData,
          PrefetchHooks Function()
        > {
  $$LocalProfileSyncCheckpointTableTableManager(
    _$CatalogDatabase db,
    $LocalProfileSyncCheckpointTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfileSyncCheckpointTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalProfileSyncCheckpointTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalProfileSyncCheckpointTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<int> latestServerRevision = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> lastSuccessfulSequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfileSyncCheckpointCompanion(
                profileId: profileId,
                latestServerRevision: latestServerRevision,
                lastSyncedAt: lastSyncedAt,
                lastSuccessfulSequence: lastSuccessfulSequence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                Value<int> latestServerRevision = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> lastSuccessfulSequence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfileSyncCheckpointCompanion.insert(
                profileId: profileId,
                latestServerRevision: latestServerRevision,
                lastSyncedAt: lastSyncedAt,
                lastSuccessfulSequence: lastSuccessfulSequence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalProfileSyncCheckpointTable,
                    LocalProfileSyncCheckpointData
                  >(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LocalProfileSyncCheckpointTable,
                    LocalProfileSyncCheckpointData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfileSyncCheckpointTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalProfileSyncCheckpointTable,
      LocalProfileSyncCheckpointData,
      $$LocalProfileSyncCheckpointTableFilterComposer,
      $$LocalProfileSyncCheckpointTableOrderingComposer,
      $$LocalProfileSyncCheckpointTableAnnotationComposer,
      $$LocalProfileSyncCheckpointTableCreateCompanionBuilder,
      $$LocalProfileSyncCheckpointTableUpdateCompanionBuilder,
      (
        LocalProfileSyncCheckpointData,
        BaseReferences<
          _$CatalogDatabase,
          $LocalProfileSyncCheckpointTable,
          LocalProfileSyncCheckpointData
        >,
      ),
      LocalProfileSyncCheckpointData,
      PrefetchHooks Function()
    >;
typedef $$LocalGuestImportAuditTableCreateCompanionBuilder =
    LocalGuestImportAuditCompanion Function({
      required String id,
      required String targetProfileId,
      required String importBatchId,
      required String status,
      Value<int> favoritesCount,
      Value<int> progressCount,
      Value<int> historyCount,
      Value<String?> errorMessage,
      required DateTime createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$LocalGuestImportAuditTableUpdateCompanionBuilder =
    LocalGuestImportAuditCompanion Function({
      Value<String> id,
      Value<String> targetProfileId,
      Value<String> importBatchId,
      Value<String> status,
      Value<int> favoritesCount,
      Value<int> progressCount,
      Value<int> historyCount,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$LocalGuestImportAuditTableFilterComposer
    extends Composer<_$CatalogDatabase, $LocalGuestImportAuditTable> {
  $$LocalGuestImportAuditTableFilterComposer({
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

  ColumnFilters<String> get targetProfileId => $composableBuilder(
    column: $table.targetProfileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importBatchId => $composableBuilder(
    column: $table.importBatchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoritesCount => $composableBuilder(
    column: $table.favoritesCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progressCount => $composableBuilder(
    column: $table.progressCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get historyCount => $composableBuilder(
    column: $table.historyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalGuestImportAuditTableOrderingComposer
    extends Composer<_$CatalogDatabase, $LocalGuestImportAuditTable> {
  $$LocalGuestImportAuditTableOrderingComposer({
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

  ColumnOrderings<String> get targetProfileId => $composableBuilder(
    column: $table.targetProfileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importBatchId => $composableBuilder(
    column: $table.importBatchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoritesCount => $composableBuilder(
    column: $table.favoritesCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressCount => $composableBuilder(
    column: $table.progressCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get historyCount => $composableBuilder(
    column: $table.historyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalGuestImportAuditTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $LocalGuestImportAuditTable> {
  $$LocalGuestImportAuditTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetProfileId => $composableBuilder(
    column: $table.targetProfileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importBatchId => $composableBuilder(
    column: $table.importBatchId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get favoritesCount => $composableBuilder(
    column: $table.favoritesCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get progressCount => $composableBuilder(
    column: $table.progressCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get historyCount => $composableBuilder(
    column: $table.historyCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$LocalGuestImportAuditTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $LocalGuestImportAuditTable,
          LocalGuestImportAuditData,
          $$LocalGuestImportAuditTableFilterComposer,
          $$LocalGuestImportAuditTableOrderingComposer,
          $$LocalGuestImportAuditTableAnnotationComposer,
          $$LocalGuestImportAuditTableCreateCompanionBuilder,
          $$LocalGuestImportAuditTableUpdateCompanionBuilder,
          (
            LocalGuestImportAuditData,
            BaseReferences<
              _$CatalogDatabase,
              $LocalGuestImportAuditTable,
              LocalGuestImportAuditData
            >,
          ),
          LocalGuestImportAuditData,
          PrefetchHooks Function()
        > {
  $$LocalGuestImportAuditTableTableManager(
    _$CatalogDatabase db,
    $LocalGuestImportAuditTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalGuestImportAuditTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalGuestImportAuditTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalGuestImportAuditTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> targetProfileId = const Value.absent(),
                Value<String> importBatchId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> favoritesCount = const Value.absent(),
                Value<int> progressCount = const Value.absent(),
                Value<int> historyCount = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalGuestImportAuditCompanion(
                id: id,
                targetProfileId: targetProfileId,
                importBatchId: importBatchId,
                status: status,
                favoritesCount: favoritesCount,
                progressCount: progressCount,
                historyCount: historyCount,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String targetProfileId,
                required String importBatchId,
                required String status,
                Value<int> favoritesCount = const Value.absent(),
                Value<int> progressCount = const Value.absent(),
                Value<int> historyCount = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalGuestImportAuditCompanion.insert(
                id: id,
                targetProfileId: targetProfileId,
                importBatchId: importBatchId,
                status: status,
                favoritesCount: favoritesCount,
                progressCount: progressCount,
                historyCount: historyCount,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalGuestImportAuditTable,
                    LocalGuestImportAuditData
                  >(table),
                  BaseReferences<
                    _$CatalogDatabase,
                    $LocalGuestImportAuditTable,
                    LocalGuestImportAuditData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalGuestImportAuditTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $LocalGuestImportAuditTable,
      LocalGuestImportAuditData,
      $$LocalGuestImportAuditTableFilterComposer,
      $$LocalGuestImportAuditTableOrderingComposer,
      $$LocalGuestImportAuditTableAnnotationComposer,
      $$LocalGuestImportAuditTableCreateCompanionBuilder,
      $$LocalGuestImportAuditTableUpdateCompanionBuilder,
      (
        LocalGuestImportAuditData,
        BaseReferences<
          _$CatalogDatabase,
          $LocalGuestImportAuditTable,
          LocalGuestImportAuditData
        >,
      ),
      LocalGuestImportAuditData,
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
  $$LocalProfileFavoritesTableTableManager get localProfileFavorites =>
      $$LocalProfileFavoritesTableTableManager(_db, _db.localProfileFavorites);
  $$LocalProfilePlaybackProgressTableTableManager
  get localProfilePlaybackProgress =>
      $$LocalProfilePlaybackProgressTableTableManager(
        _db,
        _db.localProfilePlaybackProgress,
      );
  $$LocalProfileHistoryTableTableManager get localProfileHistory =>
      $$LocalProfileHistoryTableTableManager(_db, _db.localProfileHistory);
  $$LocalProfilePreferencesTableTableManager get localProfilePreferences =>
      $$LocalProfilePreferencesTableTableManager(
        _db,
        _db.localProfilePreferences,
      );
  $$LocalProfileSyncQueueTableTableManager get localProfileSyncQueue =>
      $$LocalProfileSyncQueueTableTableManager(_db, _db.localProfileSyncQueue);
  $$LocalProfileSyncCheckpointTableTableManager
  get localProfileSyncCheckpoint =>
      $$LocalProfileSyncCheckpointTableTableManager(
        _db,
        _db.localProfileSyncCheckpoint,
      );
  $$LocalGuestImportAuditTableTableManager get localGuestImportAudit =>
      $$LocalGuestImportAuditTableTableManager(_db, _db.localGuestImportAudit);
}
