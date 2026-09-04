import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/m3u_list.dart';
import 'archive_service.dart';
import 'storage_service.dart';
import 'm3u_parser_service.dart';
import 'parental_control_service.dart';
import 'xtream_service.dart';
import 'stalker_service.dart';
import 'catalog_parser.dart';
import 'epg_service.dart';
import 'tmdb_service.dart';

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
  static const int defaultsVersion = 7;

  List<Channel> all = [];
  List<XtreamSeries> series = [];
  List<CountryBucket> countries = [];
  bool loading = true;
  bool vodLoading = false;
  bool epgLoading = false;
  String? error;
  // Nombres de fuentes (M3U/Xtream/Stalker) que fallaron por completo en el
  // ultimo intento de carga. Antes se tragaban en silencio y el usuario solo
  // veia "menos contenido" sin saber por que.
  Set<String> failedSourceNames = {};

  bool _started = false;
  bool _archiveFetched = false;
  bool _refreshing = false;
  bool _networkLoadRunning = false;
  bool _refreshAgain = false;
  DateTime? _lastLoad;
  Set<String> _trendingTitles = {};

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
    unawaited(_refreshTrending());
  }

  Future<void> _refreshTrending() async {
    final titles = await TmdbService.trendingTitles();
    if (titles.isEmpty || titles.length == _trendingTitles.length) return;
    _trendingTitles = titles;
    notifyListeners();
  }

  /// "Solo por Wi‑Fi" (Perfil > Configuracion) antes no restringia nada: se
  /// guardaba pero nadie lo leia. Ahora si esta activo y la conexion es de
  /// datos moviles, se omite el refresco remoto (el contenido cacheado y el
  /// asset local siguen mostrandose).
  Future<bool> _remoteRefreshAllowed() async {
    if (StorageService.getSetting('wifiOnly', defaultValue: false) != true) {
      return true;
    }
    try {
      final result = await Connectivity().checkConnectivity();
      // Si hay Wi‑Fi/ethernet disponible se permite; solo se bloquea cuando la
      // unica via es movil. Si la consulta falla, no bloqueamos nada.
      if (result.contains(ConnectivityResult.mobile) &&
          !result.contains(ConnectivityResult.wifi) &&
          !result.contains(ConnectivityResult.ethernet)) {
        return false;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  Future<void> _refreshContent(_AssetSources fallbackSources) async {
    if (_networkLoadRunning) {
      _refreshAgain = true;
      return;
    }
    if (!await _remoteRefreshAllowed()) {
      loading = false;
      notifyListeners();
      return;
    }
    _networkLoadRunning = true;
    final failed = <String>{};
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
        // Las pelis/series del panel se deduplican por su id único, NO por url:
        // dos titulos distintos pueden compartir la misma URL de servidor y una
        // desaparecia. El prefijo evita chocar con las urls de los canales.
        final key = channel.tvgId?.isNotEmpty == true
            ? 'id:${channel.tvgId}'
            : channel.url;
        if (seen.add(key)) refreshedChannels.add(channel);
      }
      if (lists.any((list) => list.isStalker)) {
        for (final channel in all.where(
          (channel) => channel.category == 'stalker',
        )) {
          if (seen.add(channel.url)) refreshedChannels.add(channel);
        }
      }
      for (final result in results) {
        // Solo se avisa de fuentes que el usuario agrego: una lista por
        // defecto caida es cosa nuestra, no algo que el usuario deba "arreglar".
        if (!result.success && !result.list.isDefault) {
          failed.add(result.list.name);
        }
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
      await _loadVod(lists, assetSources.series, failed);
      unawaited(_enrichMovies(all));
      unawaited(_loadArchiveCatalog());
    } catch (exception) {
      if (all.isEmpty && series.isEmpty) {
        error = exception.toString();
        loading = false;
        notifyListeners();
      }
    } finally {
      failedSourceNames = failed;
      notifyListeners();
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
    Set<String> failed,
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
      var ok = false;
      try {
        movies.addAll(
          await XtreamService.fetchMovies(a.host!, a.username!, a.password!),
        );
        ok = true;
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
        ok = true;
      } catch (_) {}
      try {
        ser.addAll(
          await XtreamService.fetchSeriesList(
            a.host!,
            a.username!,
            a.password!,
          ),
        );
        ok = true;
      } catch (_) {}
      // Solo se avisa si las TRES peticiones fallaron: la cuenta esta
      // realmente caida, no solo un endpoint suyo con un problema puntual.
      if (!ok) failed.add(a.name);
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
      } catch (_) {
        failed.add(portal.name);
      }
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

  /// Completa sinopsis/año/rating/reparto de las peliculas que llegaron sin
  /// esos datos (comun en listas M3U simples y en Archive), sin pedirle
  /// nada al usuario: primero intenta la propia info del servidor Xtream
  /// (gratis, sin API key) y si no aplica cae a TMDB por titulo. Corre en
  /// segundo plano tras la carga inicial, en tandas acotadas para no
  /// saturar la red ni pegarle de una a cientos de titulos.
  Future<void> _enrichMovies(List<Channel> movies) async {
    final needing = movies
        .where(
          (c) =>
              c.type == MediaType.movie &&
              [c.plot, c.year, c.rating].any((v) => (v ?? '').trim().isEmpty),
        )
        .take(80)
        .toList();
    if (needing.isEmpty) return;

    var changedAny = false;
    const batchSize = 6;
    for (var i = 0; i < needing.length; i += batchSize) {
      final batch = needing.skip(i).take(batchSize);
      final results = await Future.wait(
        batch.map((movie) async {
          try {
            if (await XtreamService.enrichMovieMetadata(movie)) return true;
            return await TmdbService.enrich(movie);
          } catch (_) {
            return false;
          }
        }),
      );
      if (results.any((changed) => changed)) changedAny = true;
    }
    if (changedAny) {
      notifyListeners();
      await _persistSnapshot();
    }
  }

  /// Agrega el catalogo de peliculas de dominio publico de Internet Archive
  /// (clasicos, terror, ciencia ficcion...) como contenido gratis extra,
  /// sin que el usuario tenga que configurar nada. Se pide una sola vez por
  /// sesion (no en cada `maybeRefresh`); lo ya agregado queda cacheado en el
  /// snapshot normal del catalogo, asi que un reinicio no vuelve a pedirlo
  /// hasta la siguiente carga completa.
  Future<void> _loadArchiveCatalog() async {
    if (_archiveFetched) return;
    _archiveFetched = true;
    try {
      final movies = await ArchiveService.fetchCatalog();
      if (movies.isEmpty) return;
      final favorites = StorageService.loadFavorites()
          .map((channel) => channel.url)
          .toSet();
      final existingUrls = all.map((channel) => channel.url).toSet();
      var addedAny = false;
      for (final movie in movies) {
        if (!existingUrls.add(movie.url)) continue;
        movie.isFavorite = favorites.contains(movie.url);
        all.add(movie);
        addedAny = true;
      }
      if (addedAny) {
        _recomputeCountries();
        notifyListeners();
        await _persistSnapshot();
      }
    } catch (_) {
      // Sin Internet Archive no pasa nada grave: el resto del catalogo ya
      // esta cargado y visible.
    }
  }

  /// Última versión buena del catálogo remoto, disponible sin red.
  String? _cachedRemoteSources() {
    final cached = StorageService.getSetting('remoteSourcesCache');
    return cached is String && cached.trim().isNotEmpty ? cached : null;
  }

  /// Catálogo publicado por el panel admin (KlenchoxD/hourtv-adming). Si el
  /// usuario no configura una URL propia, la app lo lee de aquí para que lo
  /// que se suba al panel aparezca solo. Se usa raw (no jsdelivr) porque su
  /// caché es de minutos, no de horas: los cambios se ven casi en el momento.
  /// Se prueban ambas ramas porque el repo usa master pero el panel trae main.
  static const List<String> _defaultCatalogUrls = [
    'https://raw.githubusercontent.com/KlenchoxD/hourtv-adming/master/catalog.json',
    'https://raw.githubusercontent.com/KlenchoxD/hourtv-adming/main/catalog.json',
  ];

  /// Descarga una nueva versión sin bloquear el primer render.
  Future<String?> _fetchRemoteSourcesFromNetwork() async {
    final configured =
        (StorageService.getSetting('remoteSourcesUrl', defaultValue: '') ?? '')
            .toString()
            .trim();
    final urls = configured.isNotEmpty ? [configured] : _defaultCatalogUrls;
    for (final url in urls) {
      try {
        // Cache-buster: evita la caché de ~5 min de raw.githubusercontent para
        // que lo recién publicado en el panel se vea de inmediato al refrescar.
        final base = Uri.parse(url);
        final fresh = base.replace(
          queryParameters: {
            ...base.queryParameters,
            '_': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
        final response = await http
            .get(
              fresh,
              headers: {
                'User-Agent': 'Mozilla/5.0',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          await StorageService.saveSetting('remoteSourcesCache', response.body);
          return response.body;
        }
      } catch (_) {}
    }
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
  void _recomputeCountries() {
    final counts = <String, int>{};
    int total = 0;
    for (final ch in visibleAll) {
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

  /// Vista pública del catálogo. La fuente completa permanece en memoria y
  /// almacenamiento; el modo restringido solo oculta entradas explícitamente
  /// adultas en los consumidores de UI.
  List<Channel>? _visibleAllCache;
  List<Channel>? _visibleAllSource;
  int _visibleAllLength = -1;
  bool _visibleAllRestricted = false;

  /// Se memoriza porque la UI lee este getter varias veces por build y filtrar
  /// el catalogo completo en cada lectura era lo que trababa el modo
  /// restringido. El cache se invalida si `all` se reemplaza, si le crecen
  /// elementos, o si cambia el estado del control parental.
  List<Channel> get visibleAll {
    final restricted = ParentalControlService.isEnabled;
    final cached = _visibleAllCache;
    if (cached != null &&
        identical(_visibleAllSource, all) &&
        _visibleAllLength == all.length &&
        _visibleAllRestricted == restricted) {
      return cached;
    }
    final filtered = ParentalControlService.filterChannels(all);
    _visibleAllCache = filtered;
    _visibleAllSource = all;
    _visibleAllLength = all.length;
    _visibleAllRestricted = restricted;
    return filtered;
  }

  List<XtreamSeries> get visibleSeries =>
      ParentalControlService.filterSeries(series);

  bool get hasRawMovies => all.any((item) => item.type == MediaType.movie);

  void refreshParentalFilter() {
    _recomputeCountries();
    notifyListeners();
  }

  void refreshProfileData() {
    final favoriteUrls = StorageService.loadFavorites()
        .map((item) => item.url)
        .toSet();
    for (final channel in all) {
      channel.isFavorite = favoriteUrls.contains(channel.url);
    }
    notifyListeners();
  }

  List<Channel> get movies =>
      visibleAll.where((c) => c.type == MediaType.movie).toList();

  /// Géneros canónicos de películas. Los nombres de fuentes y filas editoriales
  /// se agrupan como "Películas" para no contaminar los chips de Inicio.
  static const List<String> _movieGenreOrder = [
    'Infantil',
    'Anime',
    'K-Drama',
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
    if (value.contains('k-drama') ||
        value.contains('kdrama') ||
        value.contains('dorama') ||
        value.contains('korean drama') ||
        value.contains('drama coreano')) {
      return 'K-Drama';
    }
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

  // `series` (arriba) ya es la lista cruda de XtreamSeries: esta es la
  // proyeccion como Channel VOD, igual a como Mi Biblioteca filtra series.
  List<Channel> get seriesChannels =>
      visibleAll.where((c) => c.type == MediaType.series).toList();

  List<Channel> _nonLiveByCanonicalGenre(String genre) => visibleAll
      .where((c) => c.type != MediaType.live)
      .where((c) => _genresForMovie(c).contains(genre))
      .toList();

  /// Anime y K-Drama pueden venir como película o como serie: a diferencia
  /// de `moviesByGenre` (solo películas), estas dos filas del Inicio buscan
  /// en todo el catálogo VOD.
  List<Channel> get anime => _nonLiveByCanonicalGenre('Anime');

  List<Channel> get kDramas => _nonLiveByCanonicalGenre('K-Drama');

  /// Primero cruza el catálogo contra lo que TMDB marca en tendencia esta
  /// semana (popularidad real, no solo de este dispositivo). Sin conexión o
  /// sin coincidencias, cae a lo mas reproducido localmente (tambien real,
  /// via `StorageService.loadWatchCounts`) para que la fila no desaparezca.
  List<Channel> get trending {
    if (_trendingTitles.isNotEmpty) {
      final byTmdb = visibleAll
          .where((c) => c.type != MediaType.live)
          .where(
            (c) => _trendingTitles.contains(
              TmdbService.normalizeTitle(c.displayName),
            ),
          )
          .toList();
      if (byTmdb.isNotEmpty) return byTmdb;
    }
    final counts = StorageService.loadWatchCounts();
    final candidates = visibleAll
        .where((c) => c.type != MediaType.live && (counts[c.url] ?? 0) > 0)
        .toList();
    candidates.sort(
      (a, b) => (counts[b.url] ?? 0).compareTo(counts[a.url] ?? 0),
    );
    return candidates;
  }

  List<Channel> live(String genre) => visibleAll
      .where((c) => c.type == MediaType.live && c.genre == genre)
      .toList();
  List<Channel> liveByCountry(String code) => visibleAll
      .where((c) => c.type == MediaType.live && (c.countryCode ?? 'zz') == code)
      .toList();
  List<Channel> get favorites {
    // Las series del catálogo no son streams hasta que se elige un episodio,
    // así que se guardan como entradas VOD sintéticas. Se conservan aquí para
    // que "Mi Lista" pueda abrir su ficha igual que una película.
    final saved = StorageService.loadFavorites();
    final activeByUrl = {
      for (final channel in all.where((channel) => channel.isFavorite))
        channel.url: channel,
    };
    final result = <Channel>[];
    final seen = <String>{};
    for (final favorite in saved) {
      final active = activeByUrl[favorite.url];
      final item = active ?? favorite;
      item.isFavorite = true;
      if (seen.add(item.url)) result.add(item);
    }
    for (final favorite in activeByUrl.values) {
      if (seen.add(favorite.url)) result.add(favorite);
    }
    return ParentalControlService.filterChannels(result);
  }

  Future<void> toggleFavorite(Channel ch) async {
    final fav = await StorageService.toggleFavorite(ch);
    final i = all.indexWhere((c) => c.url == ch.url);
    if (i >= 0) all[i].isFavorite = fav;
    notifyListeners();
  }

  /// Todo lo reproducido recientemente, mas nuevo primero (para "Historial").
  List<Channel> get history {
    final saved = StorageService.loadRecent();
    final activeByUrl = {for (final channel in all) channel.url: channel};
    final seen = <String>{};
    final result = <Channel>[];
    for (final item in saved) {
      final active = activeByUrl[item.url];
      final merged = active ?? item;
      merged.lastWatched = item.lastWatched;
      merged.progressFraction = item.progressFraction;
      if (seen.add(merged.url)) result.add(merged);
    }
    return ParentalControlService.filterChannels(result);
  }

  /// VOD empezado pero no terminado, para la fila "Continuar viendo". En Vivo
  /// no aplica: no tiene sentido "continuar" un canal en directo.
  List<Channel> get continueWatching => history.where((item) {
    if (item.type == MediaType.live) return false;
    final fraction = item.progressFraction;
    return fraction != null && fraction > 0.02 && fraction < 0.95;
  }).toList();

  /// Guarda cuanto se avanzo en `channel` para que "Continuar viendo" refleje
  /// progreso real. Se llama desde el reproductor, no desde la UI.
  /// [notify] en false para los ticks periodicos durante la reproduccion:
  /// solo persiste, sin avisar a listeners (el shell de teléfono sigue vivo
  /// detras del reproductor y un notify cada ~10s lo reconstruye entero de
  /// fondo sin necesidad, mientras "Continuar viendo" no esta ni visible).
  /// El guardado final (al salir del reproductor) si notifica, para que la
  /// fila refleje el progreso real al volver a Inicio.
  Future<void> updatePlaybackProgress(
    Channel channel,
    double fraction, {
    bool notify = true,
  }) async {
    channel.progressFraction = fraction;
    await StorageService.updateRecentProgress(channel.url, fraction);
    if (notify) notifyListeners();
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
