import '../models/channel.dart';
import '../models/m3u_list.dart';
import 'm3u_parser_service.dart';
import 'stalker_service.dart';
import 'xtream_service.dart';

class CatalogPayload {
  final List<M3UList> lists;
  final List<String> epgUrls;
  final List<Channel> channels;
  final List<XtreamSeries> series;

  const CatalogPayload({
    this.lists = const [],
    this.epgUrls = const [],
    this.channels = const [],
    this.series = const [],
  });
}

class CatalogParser {
  static CatalogPayload parse(dynamic data) {
    final root = data is Map ? Map<dynamic, dynamic>.from(data) : null;
    final sourceItems = data is List
        ? data
        : (root?['sources'] is List ? root!['sources'] as List : const []);

    final lists = <M3UList>[];
    final epgUrls = <String>[];
    _parseSources(sourceItems, lists, epgUrls);

    if (root == null) {
      return CatalogPayload(lists: lists, epgUrls: epgUrls);
    }

    return CatalogPayload(
      lists: lists,
      epgUrls: epgUrls,
      channels: [
        ..._parseMovies(root['movies']),
        ..._parseLiveChannels(root['liveChannels']),
      ],
      series: _parseSeries(root['series']),
    );
  }

  static void _parseSources(
    dynamic raw,
    List<M3UList> lists,
    List<String> epgUrls,
  ) {
    if (raw is! List) return;
    for (final item in raw) {
      final source = _map(item);
      if (source == null) continue;
      final name = _text(source['name']) ?? 'Fuente';
      final type = (_text(source['type']) ?? 'live').toLowerCase();
      final userAgent = _text(source['userAgent'] ?? source['user_agent']);

      if (type == 'stalker') {
        final host = _text(source['host'] ?? source['url']);
        final mac = _text(source['mac'] ?? source['username']);
        if (host == null || mac == null || !StalkerService.isValidMac(mac)) {
          continue;
        }
        final normalizedHost = StalkerService.normalizePortal(host);
        lists.add(
          M3UList(
            name: name,
            url: normalizedHost,
            description: 'Portal Stalker - $normalizedHost',
            category: 'stalker',
            host: normalizedHost,
            username: StalkerService.normalizeMac(mac),
            userAgent: userAgent ?? StalkerService.magUserAgent,
          ),
        );
        continue;
      }

      if (type == 'xtream') {
        final host = _text(source['host']);
        final username = _text(source['username']);
        final password = _text(source['password']);
        if (host == null || username == null || password == null) continue;
        lists.add(
          M3UList(
            name: name,
            url: XtreamService.buildM3uUrl(host, username, password),
            category: 'xtream',
            host: XtreamService.normalizeHost(host),
            username: username,
            password: password,
            userAgent: userAgent,
          ),
        );
        continue;
      }

      final url = _text(source['url']);
      if (url == null) continue;
      if (_isEpgUrl(url) || type == 'epg' || type == 'xmltv') {
        if (!epgUrls.contains(url)) epgUrls.add(url);
        continue;
      }

      final linearPlaylist = M3UParserService.isLinearCategoryPlaylist(url);
      final mediaType =
          !linearPlaylist &&
              (type == 'movie' || type == 'movies' || type == 'peliculas')
          ? 'movie'
          : (!linearPlaylist && type == 'series' ? 'series' : null);
      final category = _text(source['category'])?.toLowerCase();
      final linearCategory = M3UParserService.linearPlaylistCategory(url);
      lists.add(
        M3UList(
          name: name,
          url: url,
          category:
              category ??
              linearCategory ??
              (mediaType == null
                  ? 'live'
                  : (mediaType == 'movie' ? 'peliculas' : 'series')),
          mediaType: mediaType,
          userAgent: userAgent,
        ),
      );
    }
  }

  static List<Channel> _parseMovies(dynamic raw) {
    if (raw is! List) return const [];
    final movies = <Channel>[];
    for (final item in raw) {
      final movie = _map(item);
      if (movie == null) continue;
      final title = _text(movie['title'] ?? movie['name']);
      final servers = _servers(movie['servers']);
      if (title == null || servers.isEmpty) continue;
      final categories = _strings(movie['categories']);
      movies.add(
        Channel(
          name: title,
          url: servers.first.url,
          logo: _text(movie['poster'] ?? movie['logo']),
          backdrop: _text(movie['backdrop']),
          tvgId: _text(movie['id']),
          group: categories.isEmpty ? null : categories.first,
          category: categories.isEmpty ? 'peliculas' : categories.first,
          genre: _text(movie['genre']),
          forcedType: 'movie',
          plot: _text(movie['plot'] ?? movie['description']),
          year: _text(movie['year']),
          rating: _text(movie['rating']),
          duration: _text(movie['duration']),
          cast: _text(movie['cast']),
          director: _text(movie['director']),
          userAgent: _text(movie['userAgent'] ?? movie['user_agent']),
          servers: servers,
          categories: categories,
          isFeatured: _truthy(movie['featured']),
        ),
      );
    }
    return movies;
  }

  static List<Channel> _parseLiveChannels(dynamic raw) {
    if (raw is! List) return const [];
    final channels = <Channel>[];
    for (final item in raw) {
      final live = _map(item);
      if (live == null) continue;
      final name = _text(live['name'] ?? live['title']);
      final url = _text(live['url']);
      if (name == null || url == null) continue;
      final group = _text(live['group'] ?? live['category']);
      channels.add(
        Channel(
          name: name,
          url: url,
          logo: _text(live['logo'] ?? live['poster']),
          group: group,
          tvgId: _text(live['id']),
          category: 'live',
          genre: group,
          userAgent: _text(live['userAgent'] ?? live['user_agent']),
        ),
      );
    }
    return channels;
  }

  static List<XtreamSeries> _parseSeries(dynamic raw) {
    if (raw is! List) return const [];
    final output = <XtreamSeries>[];
    for (var seriesIndex = 0; seriesIndex < raw.length; seriesIndex++) {
      final item = _map(raw[seriesIndex]);
      if (item == null) continue;
      final name = _text(item['title'] ?? item['name']);
      if (name == null) continue;
      final rawId = _text(item['id']) ?? '${seriesIndex + 1}';
      final seriesId = 'catalog:$rawId';
      final categories = _strings(item['categories']);
      final cover = _text(item['poster'] ?? item['cover']);
      final episodes = <Channel>[];
      final seasons = item['seasons'];
      if (seasons is List) {
        for (var seasonIndex = 0; seasonIndex < seasons.length; seasonIndex++) {
          final season = _map(seasons[seasonIndex]);
          if (season == null) continue;
          final seasonNumber = _text(season['number']) ?? '${seasonIndex + 1}';
          final rawEpisodes = season['episodes'];
          if (rawEpisodes is! List) continue;
          for (
            var episodeIndex = 0;
            episodeIndex < rawEpisodes.length;
            episodeIndex++
          ) {
            final episode = _map(rawEpisodes[episodeIndex]);
            if (episode == null) continue;
            final servers = _servers(episode['servers']);
            if (servers.isEmpty) continue;
            final episodeNumber =
                _text(episode['number']) ?? '${episodeIndex + 1}';
            final episodeTitle =
                _text(episode['title'] ?? episode['name']) ??
                'Episodio $episodeNumber';
            episodes.add(
              Channel(
                name: episodeTitle,
                url: servers.first.url,
                logo: _text(episode['poster']) ?? cover,
                group: 'T$seasonNumber',
                tvgId: '$seriesId:$seasonNumber:$episodeNumber',
                category: 'series',
                genre: _text(item['genre']),
                forcedType: 'series',
                plot: _text(episode['plot'] ?? episode['description']),
                duration: _text(episode['duration']),
                userAgent: _text(
                  episode['userAgent'] ??
                      episode['user_agent'] ??
                      item['userAgent'] ??
                      item['user_agent'],
                ),
                servers: servers,
                categories: categories,
              ),
            );
          }
        }
      }
      output.add(
        XtreamSeries(
          seriesId: seriesId,
          name: name,
          cover: cover,
          plot: _text(item['plot'] ?? item['description']),
          host: '',
          username: '',
          password: '',
          episodes: episodes,
          year: _text(item['year']),
          rating: _text(item['rating']),
          duration: _text(item['duration']),
          genre: _text(item['genre']),
          cast: _text(item['cast']),
          director: _text(item['director']),
          backdrop: _text(item['backdrop']),
          categories: categories,
          isFeatured: _truthy(item['featured']),
        ),
      );
    }
    return output;
  }

  static List<ChannelServer> _servers(dynamic raw) {
    if (raw is! List) return const [];
    final servers = <ChannelServer>[];
    for (final item in raw) {
      final server = _map(item);
      if (server == null) continue;
      final url = _text(server['url']);
      if (url == null) continue;
      final name = _text(server['name']) ?? 'Servidor ${servers.length + 1}';
      servers.add(ChannelServer(name: name, url: url));
    }
    return servers;
  }

  static Map<dynamic, dynamic>? _map(dynamic value) =>
      value is Map ? Map<dynamic, dynamic>.from(value) : null;

  static String? _text(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map(_text).whereType<String>().toSet().toList(growable: false);
  }

  static bool _truthy(dynamic value) =>
      value == true || value == 1 || value?.toString().toLowerCase() == 'true';

  static bool _isEpgUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.xml') ||
        lower.endsWith('.xml.gz') ||
        lower.contains('/epg_') ||
        lower.contains('xmltv');
  }
}
