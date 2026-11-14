import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../models/channel.dart';
import 'embed_resolver.dart';
import 'storage_service.dart';
import 'xtream_service.dart';

class Anime1vConfig {
  final String baseUrl;
  final String? apiKey;
  final bool usesDefaultBaseUrl;

  const Anime1vConfig({
    required this.baseUrl,
    this.apiKey,
    required this.usesDefaultBaseUrl,
  });
}

class _TimedCacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  const _TimedCacheEntry(this.value, this.expiresAt);

  bool get isFresh => DateTime.now().isBefore(expiresAt);
}

/// Cliente directo para FxxMorgan/anime1v-api montado en HourTV.
/// Exclusivo para contenido Anime; no interfiere con películas, series o TV.
class Anime1vService {
  Anime1vService._([
    http.Client? client,
    this._baseUrlReader,
    this._apiKeyReader,
  ]) : _client = client ?? http.Client();

  @visibleForTesting
  factory Anime1vService.forTesting({
    required http.Client client,
    String? Function()? baseUrlReader,
    String? Function()? apiKeyReader,
  }) {
    return Anime1vService._(client, baseUrlReader, apiKeyReader);
  }

  static final Anime1vService instance = Anime1vService._();

  static const String defaultBaseUrl =
      'https://hourtv-adming.vercel.app/api/v1/anime';
  static const String settingBaseUrlKey = 'animeApiUrl';
  static const String settingApiKeyKey = 'animeApiKey';
  static const String sourceHostTag = 'anime1v';
  static const String seriesChannelPrefix = 'hourtv-series:anime1v:';
  static const String episodeTicketPrefix = 'anime1v://ep?url=';
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _catalogTtl = Duration(minutes: 10);
  static const Duration _searchTtl = Duration(minutes: 3);
  static const Duration _infoTtl = Duration(minutes: 10);
  static const Duration _episodeTtl = Duration(minutes: 5);

  final http.Client _client;
  final String? Function()? _baseUrlReader;
  final String? Function()? _apiKeyReader;

  String? _remoteOverrideBaseUrl;
  bool _remoteConfigChecked = false;
  Future<void>? _remoteConfigInFlight;

  final Map<String, _TimedCacheEntry<List<XtreamSeries>>> _catalogCache = {};
  final Map<String, Future<List<XtreamSeries>>> _catalogInFlight = {};
  final Map<String, _TimedCacheEntry<List<XtreamSeries>>> _searchCache = {};
  final Map<String, Future<List<XtreamSeries>>> _searchInFlight = {};
  final Map<String, _TimedCacheEntry<XtreamSeries>> _infoCache = {};
  final Map<String, Future<XtreamSeries?>> _infoInFlight = {};
  final Map<String, _TimedCacheEntry<List<ChannelServer>>> _episodeCache = {};
  final Map<String, Future<List<ChannelServer>>> _episodeInFlight = {};
  final Map<String, Future<ResolvedStream?>> _resolveInFlight = {};

  static bool isAnime1vSeries(XtreamSeries series) {
    return series.host == sourceHostTag ||
        series.seriesId.startsWith('anime1v:');
  }

  static bool isAnime1vChannel(Channel channel) {
    return channel.url.startsWith(seriesChannelPrefix) ||
        isAnime1vEpisodeUrl(channel.url) ||
        channel.category == sourceHostTag ||
        (channel.catalogTitleId?.startsWith('anime1v:') ?? false) ||
        (channel.tvgId?.startsWith('anime1v:') ?? false);
  }

  static bool isAnime1vEpisodeUrl(String url) =>
      url.startsWith(episodeTicketPrefix);

  static String encodeEpisodeTicketUrl(String episodeUrl) =>
      '$episodeTicketPrefix${Uri.encodeComponent(episodeUrl.trim())}';

  static String? decodeEpisodeTicketUrl(String url) {
    if (!isAnime1vEpisodeUrl(url)) return null;
    final encoded = url.substring(episodeTicketPrefix.length).trim();
    if (encoded.isEmpty) return null;
    try {
      return Uri.decodeComponent(encoded);
    } catch (_) {
      return null;
    }
  }

  static String? sourceUrlFromSeriesId(String seriesId) {
    if (!seriesId.startsWith('anime1v:')) return null;
    final rest = seriesId.substring('anime1v:'.length);
    final sep = rest.indexOf(':');
    if (sep <= 0 || sep >= rest.length - 1) return null;
    final host = rest.substring(0, sep).trim();
    final slug = rest.substring(sep + 1).trim();
    if (!host.contains('.') || slug.isEmpty) return null;
    return 'https://$host/$slug';
  }

  /// Servidores conocidos soportados por `/api/v1/anime/resolve` en modo HTTP.
  static bool canResolveOnServer(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('anime1v://')) return false;
    return lower.contains('zilla-networks.com') ||
        lower.contains('yourupload.com') ||
        lower.contains('mp4upload.com') ||
        lower.contains('voe.') ||
        lower.contains('d000d.') ||
        lower.contains('dood') ||
        lower.contains('streamwish') ||
        lower.contains('wishembed') ||
        lower.contains('swish') ||
        lower.contains('filelions') ||
        lower.contains('streamtape') ||
        lower.contains('mixdrop') ||
        lower.contains('filemoon') ||
        lower.contains('uqload') ||
        lower.contains('vidoza') ||
        lower.contains('ok.ru') ||
        lower.contains('/m3u8/');
  }

  Anime1vConfig get config {
    final rawBase =
        _baseUrlReader?.call() ??
        StorageService.getSetting(settingBaseUrlKey)?.toString();
    final normalizedCustom = normalizeBaseUrl(rawBase);
    final rawKey =
        _apiKeyReader?.call() ??
        StorageService.getSetting(settingApiKeyKey)?.toString();
    final key = rawKey?.trim();
    if (normalizedCustom != null) {
      return Anime1vConfig(
        baseUrl: normalizedCustom,
        apiKey: (key == null || key.isEmpty) ? null : key,
        usesDefaultBaseUrl: false,
      );
    }
    return Anime1vConfig(
      baseUrl: _remoteOverrideBaseUrl ?? defaultBaseUrl,
      apiKey: (key == null || key.isEmpty) ? null : key,
      usesDefaultBaseUrl: true,
    );
  }

  static String? normalizeBaseUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    final cleanPath = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (cleanPath.isEmpty) {
      return '${uri.origin}/api/v1/anime';
    }
    return '${uri.origin}$cleanPath';
  }

  Future<void> saveConfig({String? baseUrl, String? apiKey}) async {
    final normalizedUrl = normalizeBaseUrl(baseUrl) ?? '';
    await StorageService.saveSetting(settingBaseUrlKey, normalizedUrl);
    await StorageService.saveSetting(settingApiKeyKey, apiKey?.trim() ?? '');
    clearCache();
  }

  void clearCache() {
    _catalogCache.clear();
    _catalogInFlight.clear();
    _searchCache.clear();
    _searchInFlight.clear();
    _infoCache.clear();
    _infoInFlight.clear();
    _episodeCache.clear();
    _episodeInFlight.clear();
    _resolveInFlight.clear();
    _remoteOverrideBaseUrl = null;
    _remoteConfigChecked = false;
    _remoteConfigInFlight = null;
  }

  Future<void> refreshRemoteConfig() {
    if (_remoteConfigChecked) return Future.value();
    final active = _remoteConfigInFlight;
    if (active != null) return active;

    final currentConfig = config;
    if (!currentConfig.usesDefaultBaseUrl) {
      _remoteConfigChecked = true;
      return Future.value();
    }

    final future = () async {
      try {
        final json = await _getJson(
          _endpointUri(currentConfig.baseUrl, 'config'),
          timeout: const Duration(seconds: 5),
        );
        final publicBase = normalizeBaseUrl(
          json?['publicBaseUrl']?.toString(),
        );
        if (publicBase != null) {
          _remoteOverrideBaseUrl = publicBase;
        }
      } catch (_) {
        // Mantiene defaultBaseUrl si /config aún no responde.
      } finally {
        _remoteConfigChecked = true;
        _remoteConfigInFlight = null;
      }
    }();
    _remoteConfigInFlight = future;
    return future;
  }

  /// Carga las primeras páginas del catálogo de anime para la sección Animes.
  Future<List<XtreamSeries>> fetchInitialCatalog({
    String provider = 'animeav1',
    int pages = 2,
    bool forceRefresh = false,
  }) async {
    await refreshRemoteConfig();
    final pageCount = pages.clamp(1, 4);
    final lists = await Future.wait([
      for (var p = 1; p <= pageCount; p++)
        fetchCatalog(page: p, provider: provider, forceRefresh: forceRefresh),
    ]);
    final merged = <XtreamSeries>[];
    final seenIds = <String>{};
    for (final list in lists) {
      for (final item in list) {
        if (seenIds.add(item.seriesId)) merged.add(item);
      }
    }
    return merged;
  }

  Future<List<XtreamSeries>> fetchCatalog({
    int page = 1,
    String? genre,
    String provider = 'animeav1',
    bool forceRefresh = false,
  }) async {
    await refreshRemoteConfig();
    final cacheKey = '$provider|${genre ?? ''}|$page';
    if (!forceRefresh) {
      final cached = _catalogCache[cacheKey];
      if (cached != null && cached.isFresh) return cached.value;
      final inFlight = _catalogInFlight[cacheKey];
      if (inFlight != null) return inFlight;
    }

    final future = () async {
      try {
        final uri = _endpointUri(config.baseUrl, 'catalog', {
          'page': '$page',
          'provider': provider,
          if (genre != null && genre.trim().isNotEmpty) 'genre': genre.trim(),
        });
        final payload = await _getJson(uri);
        final data = _asMap(payload?['data']) ?? payload;
        final rawResults = _asList(data?['results']);
        final parsed = rawResults
            .map((raw) => _parseCatalogSeries(raw, defaultProvider: provider))
            .whereType<XtreamSeries>()
            .toList(growable: false);
        _catalogCache[cacheKey] = _TimedCacheEntry(
          parsed,
          DateTime.now().add(_catalogTtl),
        );
        return parsed;
      } finally {
        _catalogInFlight.remove(cacheKey);
      }
    }();

    _catalogInFlight[cacheKey] = future;
    return future;
  }

  Future<List<XtreamSeries>> searchAnime(
    String query, {
    String? provider,
    bool forceRefresh = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    await refreshRemoteConfig();
    final normalizedKey = '${provider ?? 'multi'}|${trimmed.toLowerCase()}';
    if (!forceRefresh) {
      final cached = _searchCache[normalizedKey];
      if (cached != null && cached.isFresh) return cached.value;
      final inFlight = _searchInFlight[normalizedKey];
      if (inFlight != null) return inFlight;
    }

    final future = () async {
      try {
        final uri = _endpointUri(config.baseUrl, 'search', {
          'q': trimmed,
          if (provider != null && provider.trim().isNotEmpty)
            'provider': provider.trim(),
        });
        final payload = await _getJson(uri);
        final data = _asMap(payload?['data']) ?? payload;
        final rawResults = _asList(data?['results']);
        final seen = <String>{};
        final parsed = <XtreamSeries>[];
        for (final raw in rawResults) {
          final item = _parseCatalogSeries(
            raw,
            defaultProvider: provider ?? 'animeav1',
          );
          if (item != null && seen.add(item.seriesId)) {
            parsed.add(item);
          }
        }
        _searchCache[normalizedKey] = _TimedCacheEntry(
          parsed,
          DateTime.now().add(_searchTtl),
        );
        return parsed;
      } finally {
        _searchInFlight.remove(normalizedKey);
      }
    }();

    _searchInFlight[normalizedKey] = future;
    return future;
  }

  Future<XtreamSeries?> fetchSeriesDetails(
    XtreamSeries base, {
    bool forceRefresh = false,
  }) async {
    final targetUrl =
        ((base.sourceUrl ?? '').trim().isNotEmpty
            ? base.sourceUrl!.trim()
            : sourceUrlFromSeriesId(base.seriesId)) ??
        '';
    if (targetUrl.isEmpty) return base;
    await refreshRemoteConfig();

    if (!forceRefresh) {
      final cached = _infoCache[targetUrl];
      if (cached != null && cached.isFresh) {
        return _mergeSeriesDetails(base, cached.value);
      }
      final inFlight = _infoInFlight[targetUrl];
      if (inFlight != null) {
        final resolved = await inFlight;
        return resolved == null ? base : _mergeSeriesDetails(base, resolved);
      }
    }

    final future = () async {
      try {
        final uri = _endpointUri(config.baseUrl, 'info', {'url': targetUrl});
        final payload = await _getJson(uri);
        final data = _asMap(payload?['data']) ?? payload;
        if (data == null) return null;
        final parsed = _parseSeriesInfo(data, base);
        if (parsed != null) {
          _infoCache[targetUrl] = _TimedCacheEntry(
            parsed,
            DateTime.now().add(_infoTtl),
          );
        }
        return parsed;
      } finally {
        _infoInFlight.remove(targetUrl);
      }
    }();

    _infoInFlight[targetUrl] = future;
    final resolved = await future;
    return resolved == null ? base : _mergeSeriesDetails(base, resolved);
  }

  Future<Channel> hydrateEpisodeChannel(
    Channel episode, {
    bool forceRefresh = false,
  }) async {
    final epUrl = decodeEpisodeTicketUrl(episode.url);
    if (epUrl == null) return episode;
    final servers = await fetchEpisodeServers(epUrl, forceRefresh: forceRefresh);
    if (servers.isEmpty) return episode;
    return episode.copyWith(servers: servers);
  }

  Future<List<ChannelServer>> fetchEpisodeServers(
    String episodeUrl, {
    bool forceRefresh = false,
  }) async {
    final targetUrl = episodeUrl.trim();
    if (targetUrl.isEmpty) return const [];
    await refreshRemoteConfig();

    if (!forceRefresh) {
      final cached = _episodeCache[targetUrl];
      if (cached != null && cached.isFresh) return cached.value;
      final inFlight = _episodeInFlight[targetUrl];
      if (inFlight != null) return inFlight;
    }

    final future = () async {
      try {
        final uri = _endpointUri(config.baseUrl, 'episode', {'url': targetUrl});
        final payload = await _getJson(uri);
        final data = _asMap(payload?['data']) ?? payload;
        if (data == null) return const <ChannelServer>[];
        final parsed = _parseEpisodeServers(data);
        if (parsed.isNotEmpty) {
          _episodeCache[targetUrl] = _TimedCacheEntry(
            parsed,
            DateTime.now().add(_episodeTtl),
          );
        }
        return parsed;
      } finally {
        _episodeInFlight.remove(targetUrl);
      }
    }();

    _episodeInFlight[targetUrl] = future;
    return future;
  }

  /// Resuelve una URL de embed o mirror de episodio vía `/api/v1/anime/resolve`.
  Future<ResolvedStream?> resolveEmbed(String embedUrl) {
    final targetUrl = embedUrl.trim();
    if (targetUrl.isEmpty || isAnime1vEpisodeUrl(targetUrl)) {
      return Future.value(null);
    }
    final existing = _resolveInFlight[targetUrl];
    if (existing != null) return existing;

    final future = () async {
      try {
        await refreshRemoteConfig();
        final uri = _endpointUri(config.baseUrl, 'resolve', {'url': targetUrl});
        final payload = await _getJson(uri);
        if (payload == null) return null;
        final streamUrl = payload['streamUrl']?.toString().trim() ?? '';
        if (streamUrl.isEmpty || streamUrl == targetUrl) return null;

        final rawHeaders = _asMap(payload['headers']);
        final headers = <String, String>{};
        if (rawHeaders != null) {
          for (final entry in rawHeaders.entries) {
            final value = entry.value?.toString().trim() ?? '';
            if (value.isNotEmpty) headers[entry.key] = value;
          }
        }
        final mediaType = payload['mediaType']?.toString().toLowerCase() ?? '';
        final formatHint =
            (mediaType == 'hls' ||
                streamUrl.toLowerCase().contains('.m3u8') ||
                streamUrl.toLowerCase().contains('/m3u8/'))
            ? VideoFormat.hls
            : null;
        return ResolvedStream(streamUrl, headers, formatHint: formatHint);
      } catch (_) {
        return null;
      } finally {
        _resolveInFlight.remove(targetUrl);
      }
    }();

    _resolveInFlight[targetUrl] = future;
    return future;
  }

  Uri _endpointUri(
    String baseUrl,
    String endpoint, [
    Map<String, String>? query,
  ]) {
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final parsed = Uri.parse('$cleanBase/$endpoint');
    if (query == null || query.isEmpty) return parsed;
    return parsed.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri, {Duration? timeout}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final key = config.apiKey;
    if (key != null && key.isNotEmpty) {
      headers['x-api-key'] = key;
    }
    final response = await _client
        .get(uri, headers: headers)
        .timeout(timeout ?? _requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    return _asMap(decoded);
  }

  XtreamSeries? _parseCatalogSeries(
    dynamic raw, {
    required String defaultProvider,
  }) {
    final map = _asMap(raw);
    if (map == null) return null;
    final title = (map['title'] ?? map['name'] ?? '').toString().trim();
    final url = (map['url'] ?? map['slug'] ?? '').toString().trim();
    if (title.isEmpty || url.isEmpty) return null;

    final provider = (map['provider'] ?? defaultProvider)
        .toString()
        .trim()
        .toLowerCase();
    final cover = _cleanMediaUrl(map['image'] ?? map['poster']);
    final backdrop = _cleanMediaUrl(map['backdrop']);
    final rawGenres = _parseGenresList(map['genres']);
    final categories = _withAnimeCategory(rawGenres);
    final idFallback = (map['id'] ?? title).toString().trim();
    final seriesId = _seriesIdFor(url, provider, idFallback);

    return XtreamSeries(
      seriesId: seriesId,
      name: title,
      cover: cover,
      backdrop: backdrop,
      plot: _cleanText(map['description'] ?? map['plot']),
      host: sourceHostTag,
      username: '',
      password: '',
      year: _cleanYear(map['year']),
      rating: _cleanScore(map['score'] ?? map['rating']),
      genre: categories.join(', '),
      categories: categories,
      sourceUrl: url,
    );
  }

  XtreamSeries? _parseSeriesInfo(Map<String, dynamic> data, XtreamSeries base) {
    final title = _cleanText(data['title']) ?? base.name;
    final sourceUrl = _cleanText(data['url'] ?? data['slug']) ?? base.sourceUrl;
    final cover = _cleanMediaUrl(data['image']) ?? base.cover;
    final backdrop = _cleanMediaUrl(data['backdrop']) ?? cover ?? base.backdrop;
    final plot = _cleanText(data['description'] ?? data['plot']) ?? base.plot;
    final genres = _withAnimeCategory(_parseGenresList(data['genres']));
    final genreText = genres.join(', ');
    final year = _cleanYear(data['year'] ?? data['startDate']) ?? base.year;
    final rating = _cleanScore(data['score'] ?? data['rating']) ?? base.rating;

    final rawEpisodes = _asList(data['episodes']);
    final episodes = <Channel>[];
    for (var i = 0; i < rawEpisodes.length; i++) {
      final epMap = _asMap(rawEpisodes[i]);
      if (epMap == null) continue;
      final epUrl = (epMap['url'] ?? '').toString().trim();
      if (epUrl.isEmpty) continue;
      final number = epMap['number']?.toString().trim();
      final rawTitle = _cleanText(epMap['title']);
      final epName = _formatEpisodeName(rawTitle, number, i + 1);
      episodes.add(
        Channel(
          name: epName,
          url: encodeEpisodeTicketUrl(epUrl),
          logo: cover,
          backdrop: backdrop,
          group: 'T1',
          category: sourceHostTag,
          genre: genreText,
          forcedType: 'series',
          categories: genres,
          catalogTitleId: base.seriesId,
          plot: plot,
          year: year,
          rating: rating,
          tvgId: 'anime1v:${base.seriesId}:${number ?? (i + 1)}',
        ),
      );
    }

    return XtreamSeries(
      seriesId: base.seriesId,
      name: title,
      cover: cover,
      backdrop: backdrop,
      plot: plot,
      host: sourceHostTag,
      username: '',
      password: '',
      episodes: episodes,
      year: year,
      rating: rating,
      genre: genreText,
      categories: genres,
      sourceUrl: sourceUrl,
      anilistId: _cleanInt(data['anilistId']),
    );
  }

  XtreamSeries _mergeSeriesDetails(XtreamSeries base, XtreamSeries detailed) {
    return XtreamSeries(
      seriesId: base.seriesId,
      name: detailed.name.isNotEmpty ? detailed.name : base.name,
      cover: detailed.cover ?? base.cover,
      backdrop: detailed.backdrop ?? base.backdrop,
      plot: (detailed.plot?.isNotEmpty ?? false) ? detailed.plot : base.plot,
      host: sourceHostTag,
      username: '',
      password: '',
      episodes: (detailed.episodes != null && detailed.episodes!.isNotEmpty)
          ? detailed.episodes
          : base.episodes,
      year: detailed.year ?? base.year,
      rating: detailed.rating ?? base.rating,
      genre: (detailed.genre?.isNotEmpty ?? false)
          ? detailed.genre
          : base.genre,
      categories: detailed.categories.isNotEmpty
          ? detailed.categories
          : base.categories,
      sourceUrl: detailed.sourceUrl ?? base.sourceUrl,
      anilistId: detailed.anilistId ?? base.anilistId,
    );
  }

  List<ChannelServer> _parseEpisodeServers(Map<String, dynamic> data) {
    final collected = <_RankedServer>[];
    final seenUrls = <String>{};

    void collectGroup(dynamic group, String defaultLang) {
      if (group is List) {
        for (final entry in group) {
          final map = _asMap(entry);
          if (map == null) continue;
          final rawUrl =
              (map['url'] ?? map['code'] ?? map['link'] ?? '').toString().trim();
          final uri = Uri.tryParse(rawUrl);
          if (uri == null ||
              (uri.scheme != 'http' && uri.scheme != 'https') ||
              !seenUrls.add(rawUrl)) {
            continue;
          }
          final serverLabel =
              (map['server'] ?? map['name'] ?? uri.host).toString().trim();
          final lang =
              (map['lang'] ?? map['language'] ?? defaultLang)
                  .toString()
                  .trim()
                  .toUpperCase();
          final langTag = lang == 'DUB' ? 'DUB' : 'SUB';
          final resolvedHint = map['resolvedUrl']?.toString().trim();
          final effectiveUrl =
              (resolvedHint != null && resolvedHint.startsWith('http'))
              ? resolvedHint
              : rawUrl;
          collected.add(
            _RankedServer(
              rank: _serverPriority(serverLabel, effectiveUrl, langTag),
              server: ChannelServer(
                name: '$serverLabel ($langTag)',
                url: effectiveUrl,
                language: langTag,
              ),
            ),
          );
        }
      }
    }

    final servers = _asMap(data['servers']);
    if (servers != null) {
      collectGroup(servers['sub'] ?? servers['SUB'], 'SUB');
      collectGroup(servers['dub'] ?? servers['DUB'], 'DUB');
    }

    final streamLinks = _asMap(data['streamLinks']);
    if (streamLinks != null) {
      collectGroup(streamLinks['SUB'] ?? streamLinks['sub'], 'SUB');
      collectGroup(streamLinks['DUB'] ?? streamLinks['dub'], 'DUB');
    }

    final videos = data['videos'];
    if (videos is List) {
      collectGroup(videos, 'SUB');
    } else {
      final videoMap = _asMap(videos);
      if (videoMap != null) {
        collectGroup(videoMap['sub'] ?? videoMap['SUB'], 'SUB');
        collectGroup(videoMap['dub'] ?? videoMap['DUB'], 'DUB');
      }
    }

    collected.sort((a, b) => a.rank.compareTo(b.rank));
    return collected.map((e) => e.server).toList(growable: false);
  }

  static int _serverPriority(String name, String url, String langTag) {
    final n = name.toLowerCase();
    final u = url.toLowerCase();
    var base = 50;
    if (n.contains('hls') || u.contains('zilla-networks')) {
      base = 10;
    } else if (n.contains('mp4upload') || u.contains('mp4upload')) {
      base = 20;
    } else if (n.contains('yourupload') || u.contains('yourupload')) {
      base = 25;
    } else if (n.contains('voe') || u.contains('voe.')) {
      base = 30;
    } else if (n.contains('streamwish') ||
        n.contains('swish') ||
        u.contains('streamwish')) {
      base = 35;
    } else if (n.contains('streamtape') || u.contains('streamtape')) {
      base = 40;
    } else if (u.contains('uns.bio') || n.contains('upnshare')) {
      base = 85;
    } else if (n.contains('mega') || u.contains('mega.nz')) {
      base = 95;
    }
    return langTag == 'DUB' ? base + 5 : base;
  }

  static String _seriesIdFor(String url, String provider, String fallback) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) {
      final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      final slug = uri.pathSegments.where((s) => s.isNotEmpty).join('/');
      if (slug.isNotEmpty) return 'anime1v:$host:$slug';
    }
    final cleanFallback = fallback.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    return 'anime1v:$provider:$cleanFallback';
  }

  static String _formatEpisodeName(
    String? rawTitle,
    String? number,
    int fallbackIndex,
  ) {
    final epNum = (number != null && number.isNotEmpty)
        ? number
        : '$fallbackIndex';
    if (rawTitle == null || rawTitle.isEmpty) {
      return 'Episodio $epNum';
    }
    if (rawTitle.toLowerCase().contains('episodio') ||
        RegExp(r'^ep\.?\s*\d+', caseSensitive: false).hasMatch(rawTitle)) {
      return rawTitle;
    }
    return 'Ep. $epNum - $rawTitle';
  }

  static List<String> _parseGenresList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static List<String> _withAnimeCategory(List<String> genres) {
    final result = <String>['Anime'];
    final seen = <String>{'anime'};
    for (final g in genres) {
      final clean = g.trim();
      if (clean.isEmpty) continue;
      if (seen.add(clean.toLowerCase())) {
        result.add(clean);
      }
    }
    return result;
  }

  static String? _cleanMediaUrl(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (text.startsWith('https://') || text.startsWith('http://')) return text;
    if (text.startsWith('//')) return 'https:$text';
    return null;
  }

  static String? _cleanText(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _cleanYear(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final match = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(text);
    return match?.group(1);
  }

  static int? _cleanInt(dynamic raw) {
    if (raw is int) return raw > 0 ? raw : null;
    final parsed = int.tryParse(raw?.toString().trim() ?? '');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static String? _cleanScore(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      return raw > 0 ? raw.toString() : null;
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    return (value != null && value > 0) ? text : null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : const [];
  }
}

class _RankedServer {
  final int rank;
  final ChannelServer server;

  const _RankedServer({required this.rank, required this.server});
}
