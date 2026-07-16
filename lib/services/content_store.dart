import 'dart:async';
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
  bool _networkLoadRunning = false;
  bool _refreshAgain = false;
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
    error = null;
    _lastLoad = DateTime.now();

    // Stale-while-revalidate: restaura primero el último resultado parseado.
    // Ninguna petición HTTP forma parte de la ruta del primer render.
    if (all.isEmpty) {
      loading = true;
      notifyListeners();
      final cachedChannelsFuture = StorageService.loadChannels();
      final cachedSeriesFuture = StorageService.loadSeries();
      final cachedChannels = await cachedChannelsFuture;
      final cachedSeries = await cachedSeriesFuture;
      if (cachedChannels.isNotEmpty || cachedSeries.isNotEmpty) {
        final favorites = StorageService.loadFavorites()
            .map((channel) => channel.url)
            .toSet();
        for (final channel in cachedChannels) {
          channel.isFavorite = favorites.contains(channel.url);
        }
        all = cachedChannels;
        series = cachedSeries;
        _recomputeCountries();
        loading = false;
        notifyListeners();
      }
    }

    // El catálogo remoto cacheado o el asset local también se leen sin red.
    final localSources = await _loadAssetSources();
    if (all.isEmpty && localSources.channels.isNotEmpty) {
      all = localSources.channels;
    }
    if (series.isEmpty && localSources.series.isNotEmpty) {
      series = localSources.series;
    }
    if (all.isNotEmpty || series.isNotEmpty) {
      _recomputeCountries();
      loading = false;
      notifyListeners();
    }

    // La red siempre queda fuera de la ruta crítica del arranque.
    unawaited(_refreshContent(localSources));
  }

  Future<void> _refreshContent(_AssetSources fallbackSources) async {
    if (_networkLoadRunning) {
      _refreshAgain = true;
      return;
    }
    _networkLoadRunning = true;
    try {
      final saved = StorageService.loadLists();
      final userLists = saved.where((list) => !list.isDefault).toList();
      List<M3UList> lists;
      if (saved.isEmpty ||
          StorageService.getSetting('defaultsVersion') != defaultsVersion) {
        lists = [...M3UParserService.getDefaultLists(), ...userLists];
        await StorageService.saveLists(lists);
        await StorageService.saveSetting('defaultsVersion', defaultsVersion);
      } else {
        lists = saved;
      }

      final refreshedSources = await _loadAssetSources(refreshRemote: true);
      final assetSources = refreshedSources.isEmpty
          ? fallbackSources
          : refreshedSources;
      final byUrl = <String, M3UList>{};
      for (final list in [...lists, ...assetSources.lists]) {
        byUrl[list.isStalker ? '${list.url}|${list.username}' : list.url] =
            list;
      }
      lists = byUrl.values.toList();

      final results = await Future.wait(
        lists.where((list) => !list.isStalker).map((list) async {
          try {
            final channels = await M3UParserService.fetchAndParse(
              list.url,
              listName: list.name,
              genre: (list.mediaType == 'movie' || list.mediaType == 'series')
                  ? list.name
                  : list.category,
              mediaType: list.mediaType,
              userAgent: list.userAgent,
            );
            return (list: list, channels: channels, success: true);
          } catch (_) {
            return (list: list, channels: const <Channel>[], success: false);
          }
        }),
      );

      final seen = <String>{};
      final refreshedChannels = <Channel>[];
      for (final channel in assetSources.channels) {
        if (seen.add(channel.url)) refreshedChannels.add(channel);
      }
      if (lists.any((list) => list.isStalker)) {
        for (final channel in all.where(
          (channel) => channel.category == 'stalker',
        )) {
          if (seen.add(channel.url)) refreshedChannels.add(channel);
        }
      }
      for (final result in results) {
        final sourceChannels = result.success
            ? result.channels
            : all.where((channel) => channel.category == result.list.name);
        for (final channel in sourceChannels) {
          if (seen.add(channel.url)) refreshedChannels.add(channel);
        }
      }

      // Si una revalidación completa falla, conserva la instantánea visible.
      if (refreshedChannels.isEmpty && all.isNotEmpty) return;
      final favorites = StorageService.loadFavorites()
          .map((channel) => channel.url)
          .toSet();
      for (final channel in refreshedChannels) {
        channel.isFavorite = favorites.contains(channel.url);
      }
      all = refreshedChannels;
      series = assetSources.series;
      _recomputeCountries();
      loading = false;
      notifyListeners();
      await _persistSnapshot();

      unawaited(_loadEpg(assetSources.epgUrls));
      await _loadVod(lists, assetSources.series);
      await _loadArchive();
    } catch (exception) {
      if (all.isEmpty && series.isEmpty) {
        error = exception.toString();
        loading = false;
        notifyListeners();
      }
    } finally {
      _networkLoadRunning = false;
      if (_refreshAgain) {
        _refreshAgain = false;
        unawaited(_refreshContent(fallbackSources));
      }
    }
  }

  Future<void> _persistSnapshot() async {
    await Future.wait([
      StorageService.saveChannels(List<Channel>.from(all)),
      StorageService.saveSeries(List<XtreamSeries>.from(series)),
    ]);
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
    await _persistSnapshot();
  }

  /// Última versión buena del catálogo remoto, disponible sin red.
  String? _cachedRemoteSources() {
    final cached = StorageService.getSetting('remoteSourcesCache');
    return cached is String && cached.trim().isNotEmpty ? cached : null;
  }

  /// Descarga una nueva versión sin bloquear el primer render.
  Future<String?> _fetchRemoteSourcesFromNetwork() async {
    final url =
        (StorageService.getSetting('remoteSourcesUrl', defaultValue: '') ?? '')
            .toString()
            .trim();
    if (url.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        await StorageService.saveSetting('remoteSourcesCache', response.body);
        return response.body;
      }
    } catch (_) {}
    return null;
  }

  /// Lee primero caché/asset. Solo consulta la red cuando [refreshRemote] es
  /// true, y esa llamada se hace exclusivamente desde la revalidación de fondo.
  Future<_AssetSources> _loadAssetSources({bool refreshRemote = false}) async {
    try {
      String? raw;
      if (refreshRemote) {
        raw = await _fetchRemoteSourcesFromNetwork();
      }
      raw ??= _cachedRemoteSources();
      raw ??= await rootBundle.loadString('assets/data/sources.json');
      final parsed = CatalogParser.parse(jsonDecode(raw));
      return _AssetSources(
        parsed.lists,
        parsed.epgUrls,
        parsed.channels,
        parsed.series,
      );
    } catch (_) {
      return const _AssetSources([], [], [], []);
    }
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
    await _persistSnapshot();
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

  bool get isEmpty =>
      lists.isEmpty && epgUrls.isEmpty && channels.isEmpty && series.isEmpty;
}
