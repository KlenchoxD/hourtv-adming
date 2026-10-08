import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'xtream_service.dart';

// Punctuation can identify a sequel (K-On! / K-On!!); keep it and Unicode.
String normalizeAnimeTitle(String value) {
  var title = value.trim().toLowerCase();
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n'};
  accents.forEach((accent, plain) => title = title.replaceAll(accent, plain));
  return title
      .replaceAll(RegExp(r'[-‐‑‒–—]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool isCalendarAnime(XtreamSeries series) =>
    series.anilistId != null ||
    [...series.categories, series.genre ?? ''].any(
      (value) => RegExp(r'\banime\b', caseSensitive: false).hasMatch(value),
    ) ||
    Uri.tryParse(series.sourceUrl ?? '')?.host == 'tokianime.tv';

Set<String> animeCatalogAliases(XtreamSeries series) {
  final source = Uri.tryParse(series.sourceUrl ?? '');
  return {
    normalizeAnimeTitle(series.name),
    if (source?.host == 'tokianime.tv' &&
        source!.pathSegments.length == 2 &&
        source.pathSegments.first == 'anime')
      normalizeAnimeTitle(source.pathSegments.last.replaceAll('-', ' ')),
  }..remove('');
}

class AnimeAiringMedia {
  const AnimeAiringMedia({
    required this.id,
    required this.title,
    required this.aliases,
    required this.status,
    this.poster,
    this.adult = false,
  });
  final int id;
  final String title;
  final Set<String> aliases;
  final String status;
  final String? poster;
  final bool adult;

  String? get statusLabel => switch (status) {
    'RELEASING' => 'En emisión',
    'FINISHED' => 'Finalizado',
    'NOT_YET_RELEASED' => 'Próximamente',
    'HIATUS' => 'En pausa',
    'CANCELLED' => 'Cancelado',
    _ => null,
  };

  factory AnimeAiringMedia.fromJson(Map<String, dynamic> json) {
    final names = json['title'] as Map? ?? const {};
    final allNames = [
      names['romaji'],
      names['english'],
      names['native'],
      ...?json['synonyms'] as List?,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return AnimeAiringMedia(
      id: (json['id'] as num).toInt(),
      title: allNames.firstOrNull ?? 'Anime',
      aliases: allNames.map(normalizeAnimeTitle).toSet()..remove(''),
      status: json['status']?.toString() ?? '',
      poster: (json['coverImage'] as Map?)?['large']?.toString(),
      adult: json['isAdult'] == true,
    );
  }
}

class AnimeAiringEntry {
  const AnimeAiringEntry({
    required this.media,
    required this.episode,
    required this.airingAt,
  });
  final AnimeAiringMedia media;
  final int episode;
  final DateTime airingAt;

  factory AnimeAiringEntry.fromJson(Map<String, dynamic> json) =>
      AnimeAiringEntry(
        media: AnimeAiringMedia.fromJson(
          Map<String, dynamic>.from(json['media'] as Map),
        ),
        episode: (json['episode'] as num).toInt(),
        airingAt: DateTime.fromMillisecondsSinceEpoch(
          (json['airingAt'] as num).toInt() * 1000,
          isUtc: true,
        ),
      );
}

/// Exact aliases or explicit ids only: never guess a season by a partial title.
class AnimeCatalogIndex {
  AnimeCatalogIndex(Iterable<XtreamSeries> series) {
    for (final item in series.where(isCalendarAnime)) {
      if (item.anilistId != null) {
        _ids.putIfAbsent(item.anilistId!, () => []).add(item);
        continue;
      }
      for (final alias in animeCatalogAliases(item)) {
        _aliases.putIfAbsent(alias, () => []).add(item);
      }
    }
  }
  final _ids = <int, List<XtreamSeries>>{};
  final _aliases = <String, List<XtreamSeries>>{};

  XtreamSeries? match(AnimeAiringMedia media) {
    final exact = _ids[media.id];
    if (exact != null) return exact.length == 1 ? exact.single : null;
    final candidates = <XtreamSeries>{
      for (final alias in media.aliases) ...?_aliases[alias],
    };
    return candidates.length == 1 ? candidates.single : null;
  }
}

class AnimeScheduleResult {
  const AnimeScheduleResult(this.entries, {this.stale = false});
  final List<AnimeAiringEntry> entries;
  final bool stale;
}

class AnimeScheduleException implements Exception {
  const AnimeScheduleException();
}

/// Lazy, paginated weekly requests. No API key or Home startup work required.
class AnimeScheduleService {
  AnimeScheduleService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;
  static final instance = AnimeScheduleService();
  final http.Client _client;
  final DateTime Function() _now;
  final _pending = <String, Future<AnimeScheduleResult>>{};
  final _lookups = <String, ({DateTime at, Future<AnimeAiringMedia?> value})>{};
  static const _prefix = 'hourtv.anime-calendar.v1.';
  static const _fields = '''id status title { romaji english native }
    synonyms isAdult coverImage { large }''';

  static DateTime weekStart(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day - local.weekday + 1);
  }

  Future<Map<String, dynamic>> _query(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final response = await _client
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'query': query, 'variables': variables}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw const AnimeScheduleException();
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['errors'] != null || payload['data'] is! Map) {
      throw const AnimeScheduleException();
    }
    return Map<String, dynamic>.from(payload['data'] as Map);
  }

  Future<AnimeScheduleResult> loadWeek(DateTime date, {bool refresh = false}) {
    final start = weekStart(date);
    // Offset forms part of the key so a timezone change invalidates day bounds.
    final key = '$_prefix${start.millisecondsSinceEpoch}';
    return _pending.putIfAbsent(key, () async {
      try {
        return await _loadWeek(start, key, refresh);
      } finally {
        _pending.remove(key);
      }
    });
  }

  Future<AnimeScheduleResult> _loadWeek(
    DateTime start,
    String key,
    bool refresh,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    Map<String, dynamic>? saved;
    try {
      final raw = preferences.getString(key);
      if (raw != null) saved = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      /* Invalid cache must not prevent a fresh request. */
    }
    List<AnimeAiringEntry> decode(List raw) {
      final end = DateTime(start.year, start.month, start.day + 7);
      final unique = <String, AnimeAiringEntry>{};
      for (final item in raw.whereType<Map>()) {
        final entry = AnimeAiringEntry.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (!entry.media.adult &&
            !entry.airingAt.isBefore(start) &&
            entry.airingAt.isBefore(end)) {
          unique['${entry.media.id}:${entry.episode}:${entry.airingAt}'] =
              entry;
        }
      }
      return unique.values.toList()
        ..sort((a, b) => a.airingAt.compareTo(b.airingAt));
    }

    try {
      final at = DateTime.tryParse(saved?['savedAt']?.toString() ?? '');
      if (!refresh &&
          at != null &&
          _now().difference(at) >= Duration.zero &&
          _now().difference(at) < const Duration(hours: 4)) {
        return AnimeScheduleResult(decode(saved!['entries'] as List));
      }
    } catch (_) {
      saved = null;
    }
    try {
      final end = DateTime(start.year, start.month, start.day + 7);
      final rows = <Map<String, dynamic>>[];
      var complete = false;
      for (var page = 1; page <= 12; page++) {
        final data = await _query(
          '''query(\$start:Int,\$end:Int,\$page:Int) {
          Page(page:\$page, perPage:50) { pageInfo { hasNextPage }
            airingSchedules(airingAt_greater:\$start, airingAt_lesser:\$end, sort:TIME) {
              airingAt episode media { $_fields }
            }
          }
        }''',
          {
            'start': start.millisecondsSinceEpoch ~/ 1000 - 1,
            'end': end.millisecondsSinceEpoch ~/ 1000,
            'page': page,
          },
        );
        final result = data['Page'] as Map;
        rows.addAll(
          (result['airingSchedules'] as List).whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
        if ((result['pageInfo'] as Map)['hasNextPage'] != true) {
          complete = true;
          break;
        }
      }
      if (!complete) throw const AnimeScheduleException();
      final sorted = decode(rows);
      await preferences.setString(
        key,
        jsonEncode({'savedAt': _now().toIso8601String(), 'entries': rows}),
      );
      // Keep at most eight weekly caches, with no access to unrelated settings.
      final oldKeys =
          preferences
              .getKeys()
              .where((k) => k.startsWith(_prefix) && k != key)
              .toList()
            ..sort();
      while (oldKeys.length > 7) {
        await preferences.remove(oldKeys.removeAt(0));
      }
      return AnimeScheduleResult(sorted);
    } catch (_) {
      if (saved != null) {
        try {
          return AnimeScheduleResult(
            decode(saved['entries'] as List),
            stale: true,
          );
        } catch (_) {
          /* Invalid cache is an error, not an empty calendar. */
        }
      }
      throw const AnimeScheduleException();
    }
  }

  Future<AnimeAiringMedia?> lookup(XtreamSeries series) {
    if (!isCalendarAnime(series)) return Future.value();
    final key =
        '${series.seriesId}|${series.name}|${series.anilistId}|${series.sourceUrl}';
    final cached = _lookups[key];
    if (cached != null &&
        _now().difference(cached.at) < const Duration(hours: 4)) {
      return cached.value;
    }
    final future = _lookup(series);
    _lookups[key] = (at: _now(), value: future);
    return future;
  }

  Future<AnimeAiringMedia?> _lookup(XtreamSeries series) async {
    try {
      if (series.anilistId != null) {
        final data = await _query(
          'query(\$id:Int){Media(id:\$id,type:ANIME){$_fields}}',
          {'id': series.anilistId},
        );
        return AnimeAiringMedia.fromJson(
          Map<String, dynamic>.from(data['Media'] as Map),
        );
      }
      final index = AnimeCatalogIndex([series]);
      final seen = <String>{};
      final queries = <String>{
        series.name,
        ...animeCatalogAliases(series),
      }.where((query) => seen.add(normalizeAnimeTitle(query))).take(2);
      for (final search in queries) {
        final data = await _query(
          '''query(\$search:String){Page(perPage:5){media(search:\$search,type:ANIME,isAdult:false){$_fields}}}''',
          {'search': search},
        );
        final candidates = ((data['Page'] as Map)['media'] as List)
            .whereType<Map>()
            .map((m) => AnimeAiringMedia.fromJson(Map<String, dynamic>.from(m)))
            .where((m) => index.match(m) != null)
            .toList();
        if (candidates.length == 1) return candidates.single;
      }
    } catch (_) {
      /* Unknown status is deliberately not displayed as airing. */
    }
    return null;
  }
}
