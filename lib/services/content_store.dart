import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/m3u_list.dart';
import 'storage_service.dart';
import 'm3u_parser_service.dart';
import 'xtream_service.dart';
import 'stalker_service.dart';
import 'archive_service.dart';
import 'catalog_parser.dart';
import 'epg_service.dart';

/// Agrupacion de canales por país (para el selector EN VIVO).
class CountryBucket {
  final String code; // 'all' = Todos, o codigo ISO, 'zz' = Otros
  final String name;
  final int count;
  const CountryBucket(this.code, this.name, this.count);
}

/// Almacén único en memoria del contenido (canales en vivo + VOD). Lo comparten
/// las pestañas Inicio y En Vivo para no descargar las listas dos veces.
class ContentStore extends ChangeNotifier {
  ContentStore._();
  static final ContentStore instance = ContentStore._();

  /// Sube este número cuando cambien las listas por defecto para refrescarlas
  /// sin borrar las fuentes que el usuario haya agregado.
  static const int defaultsVersion = 6;

  List<Channel> all = [];
  List<XtreamSeries> series = [];
  List<CountryBucket> countries = [];
  bool loading = true;
  bool vodLoading = false;
  bool epgLoading = false;
  String? error;

  bool _started = false;
  bool _refreshing = false;
  DateTime? _lastLoad;

  /// Carga una sola vez (la primera pestaña que la pida dispara la carga).
  Future<void> ensureLoaded() async {
    if (_started) return;
    _started = true;
    await load();
  }

  Future<void> reload() async {
    _started = true;
    await load();
  }

  /// Refresco "en tiempo real": vuelve a descargar el catálogo remoto en
  /// segundo plano (sin pantalla de carga, el contenido actual sigue visible)
  /// cuando la app vuelve al frente. Limitado a una vez cada 15 s para no
  /// martillar el servidor. Solo actúa si ya hubo una primera carga.
  Future<void> maybeRefresh() async {
    if (!_started || _refreshing) return;
    final last = _lastLoad;
    if (last != null && DateTime.now().difference(last).inSeconds < 15) return;
    _refreshing = true;
    try {
      await load();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> load() async {
    // Solo mostramos la pantalla de carga en el primer arranque; en refrescos
    // posteriores mantenemos el contenido visible para que no parpadee.
    if (all.isEmpty) {
      loading = true;
      notifyListeners();
    }
    error = null;
    _lastLoad = DateTime.now();
    try {
      final saved = StorageService.loadLists();
      final userLists = saved.where((l) => !l.isDefault).toList();
      List<M3UList> lists;
      if (saved.isEmpty ||
          StorageService.getSetting('defaultsVersion') != defaultsVersion) {
        lists = [...M3UParserService.getDefaultLists(), ...userLists];
        await StorageService.saveLists(lists);
        await StorageService.saveSetting('defaultsVersion', defaultsVersion);
      } else {
        lists = saved;
      }

      // Fuentes que el usuario agrega con el script de PC (assets/data/sources.json)
      final assetSources = await _loadAssetSources();
      final assetLists = assetSources.lists;
      final byUrl = <String, M3UList>{};
      for (final l in [...lists, ...assetLists]) {
        byUrl[l.isStalker ? '${l.url}|${l.username}' : l.url] = l;
      }
      lists = byUrl.values.toList();

      final results = await Future.wait(
        lists
            .where((l) => !l.isStalker)
            .map(
              (l) => M3UParserService.fetchAndParse(
                l.url,
                listName: l.name,
                genre: (l.mediaType == 'movie' || l.mediaType == 'series')
                    ? l.name
                    : l.category,
                mediaType: l.mediaType,
                userAgent: l.userAgent,
              ).catchError((_) => <Channel>[]),
            ),
      );

      final seen = <String>{};
      final deduped = <Channel>[];
      for (final channel in assetSources.channels) {
        if (seen.add(channel.url)) deduped.add(channel);
      }
      for (final r in results) {
        for (final ch in r) {
          if (seen.add(ch.url)) deduped.add(ch);
        }
      }

      final favs = StorageService.loadFavorites().map((c) => c.url).toSet();
      for (final ch in deduped) {
        if (favs.contains(ch.url)) ch.isFavorite = true;
      }
      all = deduped;
      series = assetSources.series;
      _recomputeCountries();
      loading = false;
      notifyListeners();

      _loadEpg(assetSources.epgUrls); // guia EPG/XMLTV, en segundo plano
      _loadVod(
        lists,
        assetSources.series,
      ); // peliculas y series desde la API Xtream, en segundo plano
      _loadArchive(); // peliculas de dominio publico (Internet Archive)
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadVod(
    List<M3UList> lists,
    List<XtreamSeries> catalogSeries,
  ) async {
    final accounts = lists.where((l) => l.isXtream).toList();
    final portals = lists.where((l) => l.isStalker).toList();
    if (accounts.isEmpty && portals.isEmpty) return;
    vodLoading = true;
    notifyListeners();
    final movies = <Channel>[];
    final liveMetadata = <Channel>[];
    final stalkerChannels = <Channel>[];
    final ser = <XtreamSeries>[];
    for (final a in accounts) {
      try {
        movies.addAll(
          await XtreamService.fetchMovies(a.host!, a.username!, a.password!),
        );
      } catch (_) {}
      try {
        liveMetadata.addAll(
          await XtreamService.fetchLiveStreams(
            a.host!,
            a.username!,
            a.password!,
            userAgent: a.userAgent,
          ),
        );
      } catch (_) {}
      try {
        ser.addAll(
          await XtreamService.fetchSeriesList(
            a.host!,
            a.username!,
            a.password!,
          ),
        );
      } catch (_) {}
    }
    for (final portal in portals) {
      try {
        stalkerChannels.addAll(
          await StalkerService.fetchChannels(
            portal.host!,
            portal.username!,
            sourceName: portal.name,
          ),
        );
      } catch (_) {}
    }

    final byUrl = {for (final channel in all) channel.url: channel};
    for (final metadata in liveMetadata) {
      final existing = byUrl[metadata.url];
      if (existing != null) {
        existing.hasCatchup = metadata.hasCatchup;
        existing.userAgent ??= metadata.userAgent;
      } else {
        all.add(metadata);
        byUrl[metadata.url] = metadata;
      }
    }
    final favorites = StorageService.loadFavorites().map((c) => c.url).toSet();
    for (final channel in [...movies, ...stalkerChannels]) {
      if (byUrl.containsKey(channel.url)) continue;
      channel.isFavorite = favorites.contains(channel.url);
      all.add(channel);
      byUrl[channel.url] = channel;
    }
    final seenSeries = <String>{};
    series = [
      for (final item in [...catalogSeries, ...ser])
        if (seenSeries.add(item.name.trim().toLowerCase())) item,
    ];
    vodLoading = false;
    _recomputeCountries();
    notifyListeners();
  }

  /// Catálogo remoto: mismo formato que sources.json pero hospedado en un
  /// servidor del dueño de la app (ej. GitHub raw). Permite actualizar
  /// fuentes y catálogo sin recompilar. Devuelve null si no hay URL
  /// configurada o no se pudo descargar (y no hay copia cacheada).
  Future<String?> _fetchRemoteSources() async {
    final url =
        (StorageService.getSetting('remoteSourcesUrl', defaultValue: '') ?? '')
            .toString()
            .trim();
    if (url.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        // Guardar la última copia buena para arrancar sin internet.
        await StorageService.saveSetting('remoteSourcesCache', res.body);
        return res.body;
      }
    } catch (_) {}
    final cached = StorageService.getSetting('remoteSourcesCache');
    return cached is String && cached.trim().isNotEmpty ? cached : null;
  }

  /// Lee las fuentes del catálogo remoto (si está configurado) o del archivo
  /// empaquetado (assets/data/sources.json). Formato: lista de objetos con
  /// { name, url, type: live|movie|series|xtream|stalker, host, mac }.
  Future<_AssetSources> _loadAssetSources() async {
    try {
      final raw =
          await _fetchRemoteSources() ??
          await rootBundle.loadString('assets/data/sources.json');
      final data = jsonDecode(raw);
      if (data is Map) {
        final parsed = CatalogParser.parse(data);
        return _AssetSources(
          parsed.lists,
          parsed.epgUrls,
          parsed.channels,
          parsed.series,
        );
      }
      if (data is! List) return const _AssetSources([], [], [], []);
      final out = <M3UList>[];
      final epgUrls = <String>[];
      for (final e in data) {
        if (e is! Map) continue;
        final name = (e['name'] ?? 'Fuente').toString();
        final type = (e['type'] ?? 'live').toString().toLowerCase();
        if (type == 'stalker') {
          final host = (e['host'] ?? e['url'] ?? '').toString();
          final mac = (e['mac'] ?? e['username'] ?? '').toString();
          if (host.isEmpty || !StalkerService.isValidMac(mac)) continue;
          final normalizedHost = StalkerService.normalizePortal(host);
          out.add(
            M3UList(
              name: name,
              url: normalizedHost,
              description: 'Portal Stalker · $normalizedHost',
              category: 'stalker',
              host: normalizedHost,
              username: StalkerService.normalizeMac(mac),
              userAgent: StalkerService.magUserAgent,
            ),
          );
        } else if (type == 'xtream') {
          final host = (e['host'] ?? '').toString();
          final user = (e['username'] ?? '').toString();
          final pass = (e['password'] ?? '').toString();
          if (host.isEmpty || user.isEmpty || pass.isEmpty) continue;
          out.add(
            M3UList(
              name: name,
              url: XtreamService.buildM3uUrl(host, user, pass),
              category: 'xtream',
              host: XtreamService.normalizeHost(host),
              username: user,
              password: pass,
            ),
          );
        } else {
          final url = (e['url'] ?? '').toString();
          if (url.isEmpty) continue;
          if (_isEpgUrl(url) || type == 'epg' || type == 'xmltv') {
            if (!epgUrls.contains(url)) epgUrls.add(url);
            continue;
          }
          final linearPlaylist = M3UParserService.isLinearCategoryPlaylist(url);
          final mt =
              !linearPlaylist &&
                  (type == 'movie' || type == 'movies' || type == 'peliculas')
              ? 'movie'
              : (!linearPlaylist && type == 'series' ? 'series' : null);
          final category = (e['category'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final linearCategory = M3UParserService.linearPlaylistCategory(url);
          final ua = (e['userAgent'] ?? e['user_agent'] ?? '')
              .toString()
              .trim();
          out.add(
            M3UList(
              name: name,
              url: url,
              category: category.isNotEmpty
                  ? category
                  : (linearCategory ??
                        (mt == null
                            ? 'live'
                            : (mt == 'movie' ? 'peliculas' : 'series'))),
              mediaType: mt,
              userAgent: ua.isEmpty ? null : ua,
            ),
          );
        }
      }
      return _AssetSources(out, epgUrls, const [], const []);
    } catch (_) {
      return const _AssetSources([], [], [], []);
    }
  }

  bool _isEpgUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.xml') ||
        lower.endsWith('.xml.gz') ||
        lower.contains('/epg_') ||
        lower.contains('xmltv');
  }

  Future<void> _loadEpg(List<String> urls) async {
    if (urls.isEmpty || all.isEmpty) return;
    epgLoading = true;
    notifyListeners();
    try {
      await EpgService.attachNowNext(all, urls);
    } catch (_) {}
    epgLoading = false;
    notifyListeners();
  }

  bool moviesLoading = false;

  /// Carga películas de dominio público (legal) para llenar el catálogo Inicio.
  Future<void> _loadArchive() async {
    moviesLoading = true;
    notifyListeners();
    try {
      final movies = await ArchiveService.fetchCatalog();
      final seen = all.map((c) => c.url).toSet();
      for (final m in movies) {
        if (seen.add(m.url)) all.add(m);
      }
    } catch (_) {}
    moviesLoading = false;
    notifyListeners();
  }

  void _recomputeCountries() {
    final counts = <String, int>{};
    int total = 0;
    for (final ch in all) {
      if (ch.type != MediaType.live) continue;
      total++;
      final code = ch.countryCode ?? 'zz';
      counts[code] = (counts[code] ?? 0) + 1;
    }
    final buckets =
        counts.entries
            .map(
              (e) => CountryBucket(
                e.key,
                e.key == 'zz'
                    ? 'Otros'
                    : (kCountryNames[e.key] ?? e.key.toUpperCase()),
                e.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            if (a.code == 'zz') return 1;
            if (b.code == 'zz') return -1;
            return b.count.compareTo(a.count);
          });
    countries = [CountryBucket('all', 'Todos', total), ...buckets];
  }

  // -------- Accesores para el catálogo (Inicio) --------

  List<Channel> get movies =>
      all.where((c) => c.type == MediaType.movie).toList();

  /// Géneros canónicos de películas. Los nombres de fuentes y filas editoriales
  /// se agrupan como "Películas" para no contaminar los chips de Inicio.
  static const List<String> _movieGenreOrder = [
    'Infantil',
    'Anime',
    'Acción',
    'Aventura',
    'Comedia',
    'Drama',
    'Terror',
    'Suspenso',
    'Romance',
    'Ciencia ficción',
    'Crimen',
    'Documental',
    'Fantasía',
    'Historia',
    'Música',
    'Guerra',
    'Western',
  ];

  String? _canonicalMovieGenre(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value.contains('anime')) return 'Anime';
    if (value.contains('infantil') ||
        value.contains('family') ||
        value.contains('familia') ||
        value.contains('kids') ||
        value.contains('children') ||
        value.contains('animaci') ||
        value.contains('animation')) {
      return 'Infantil';
    }
    if (value.contains('ciencia') ||
        value.contains('science fiction') ||
        value.contains('sci-fi')) {
      return 'Ciencia ficción';
    }
    if (value.contains('acci') || value == 'action') return 'Acción';
    if (value.contains('aventura') || value == 'adventure') {
      return 'Aventura';
    }
    if (value.contains('comedia') || value == 'comedy') return 'Comedia';
    if (value.contains('drama')) return 'Drama';
    if (value.contains('terror') || value.contains('horror')) return 'Terror';
    if (value.contains('suspenso') || value.contains('thriller')) {
      return 'Suspenso';
    }
    if (value.contains('romance')) return 'Romance';
    if (value.contains('crimen') || value.contains('crime')) return 'Crimen';
    if (value.contains('documental') || value.contains('documentary')) {
      return 'Documental';
    }
    if (value.contains('fantas') || value.contains('fantasy')) {
      return 'Fantasía';
    }
    if (value.contains('historia') || value == 'history') return 'Historia';
    if (value.contains('música') ||
        value.contains('musica') ||
        value == 'music') {
      return 'Música';
    }
    if (value.contains('guerra') || value == 'war') return 'Guerra';
    if (value.contains('western')) return 'Western';
    if (value.contains('película') ||
        value.contains('pelicula') ||
        value.contains('movie') ||
        value.contains('vod') ||
        value.contains('iptv') ||
        value.contains('archive')) {
      return 'Películas';
    }
    return null;
  }

  Set<String> _genresForMovie(Channel movie) {
    final genres = <String>{};
    final values = <String>[
      if (movie.genre != null) movie.genre!,
      ...movie.categories,
    ];
    for (final value in values) {
      for (final part in value.split(RegExp(r'[,/|]'))) {
        final genre = _canonicalMovieGenre(part);
        if (genre != null) genres.add(genre);
      }
    }
    if (genres.isEmpty) genres.add('Películas');
    return genres;
  }

  List<String> get movieGenres {
    final available = <String>{};
    for (final movie in movies) {
      available.addAll(_genresForMovie(movie));
    }
    return [
      'Películas',
      for (final genre in _movieGenreOrder)
        if (available.contains(genre)) genre,
    ];
  }

  List<Channel> moviesByGenre(String genre) {
    if (genre == 'Películas') return movies;
    final canonical = _canonicalMovieGenre(genre);
    if (canonical == null || canonical == 'Películas') return movies;
    return movies
        .where((movie) => _genresForMovie(movie).contains(canonical))
        .toList();
  }

  List<Channel> live(String genre) =>
      all.where((c) => c.type == MediaType.live && c.genre == genre).toList();
  List<Channel> liveByCountry(String code) => all
      .where((c) => c.type == MediaType.live && (c.countryCode ?? 'zz') == code)
      .toList();
  List<Channel> get favorites => all.where((c) => c.isFavorite).toList();

  Future<void> toggleFavorite(Channel ch) async {
    final fav = await StorageService.toggleFavorite(ch);
    final i = all.indexWhere((c) => c.url == ch.url);
    if (i >= 0) all[i].isFavorite = fav;
    notifyListeners();
  }
}

class _AssetSources {
  final List<M3UList> lists;
  final List<String> epgUrls;
  final List<Channel> channels;
  final List<XtreamSeries> series;
  const _AssetSources(this.lists, this.epgUrls, this.channels, this.series);
}
