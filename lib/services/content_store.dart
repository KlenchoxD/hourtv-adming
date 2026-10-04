import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/m3u_list.dart';
import 'storage_service.dart';
import 'm3u_parser_service.dart';
import 'parental_control_service.dart';
import 'xtream_service.dart';
import 'stalker_service.dart';
import 'catalog_parser.dart';
import 'epg_service.dart';
import 'content_fingerprint.dart';
import 'tmdb_service.dart';
import 'supabase_bootstrap.dart';
import '../new_ui/hourtv_web_live_policy.dart';

/// Agrupacion de canales por país (para el selector EN VIVO).
class CountryBucket {
  final String code; // 'all' = Todos, o codigo ISO, 'zz' = Otros
  final String name;
  final int count;
  const CountryBucket(this.code, this.name, this.count);
}

enum CatalogLoadPhase {
  restoringSession,
  openingCache,
  syncingCatalog,
  buildingHome,
  ready,
  readyWithContent,
  readyEmpty,
  offlineReady,
  failed,
}

class CatalogReadiness {
  const CatalogReadiness(this.phase, {this.message, this.canRetry = false});
  final CatalogLoadPhase phase;
  final String? message;
  final bool canRetry;
  bool get canEnterApp =>
      phase == CatalogLoadPhase.ready ||
      phase == CatalogLoadPhase.readyWithContent ||
      phase == CatalogLoadPhase.readyEmpty ||
      phase == CatalogLoadPhase.offlineReady;
}

/// Almacén único en memoria del contenido (canales en vivo + VOD). Lo comparten
/// las pestañas Inicio y En Vivo para no descargar las listas dos veces.
class ContentStore extends ChangeNotifier {
  ContentStore._();
  static final ContentStore instance = ContentStore._();

  /// Sube este número cuando cambien las listas por defecto para refrescarlas
  /// sin borrar las fuentes que el usuario haya agregado.
  static const int defaultsVersion = 9;

  List<Channel> all = [];
  List<XtreamSeries> series = [];
  List<CountryBucket> countries = [];
  bool _legacyLoading = false;
  // Web-only readiness: a cached movie catalogue does not mean TV lists
  // have finished loading. Native builds never consult this flag.
  bool _webLiveLoading = false;
  bool get loading =>
      _legacyLoading ||
      (kIsWeb && _webLiveLoading) ||
      (!readiness.canEnterApp && readiness.phase != CatalogLoadPhase.failed);
  set loading(bool val) {
    _legacyLoading = val;
    notifyListeners();
  }

  bool vodLoading = false;
  bool epgLoading = false;
  String? error;
  // Nombres de fuentes (M3U/Xtream/Stalker) que fallaron por completo en el
  // ultimo intento de carga. Antes se tragaban en silencio y el usuario solo
  // veia "menos contenido" sin saber por que.
  Set<String> failedSourceNames = {};

  CatalogReadiness _readiness = const CatalogReadiness(
    CatalogLoadPhase.restoringSession,
  );
  CatalogReadiness get readiness => _readiness;

  Completer<void> _initialReadyCompleter = Completer<void>();
  Future<void> get initialReady => _initialReadyCompleter.future;
  bool get isInitialReady => _initialReadyCompleter.isCompleted;

  void _setReadiness(CatalogReadiness next) {
    _readiness = next;
    notifyListeners();
    if ((next.canEnterApp || next.phase == CatalogLoadPhase.failed) &&
        !_initialReadyCompleter.isCompleted) {
      _initialReadyCompleter.complete();
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _initialReadyCompleter = Completer<void>();
    _readiness = const CatalogReadiness(CatalogLoadPhase.restoringSession);
    all = [];
    series = [];
    countries = [];
    _started = false;
    _refreshing = false;
    _networkLoadRunning = false;
    _refreshAgain = false;
    _legacyLoading = false;
    _webLiveLoading = false;
    error = null;
    failedSourceNames = {};
    _visibleSeriesCache = null;
    _genreCategoryCache.clear();
    _trendingCache = null;
    _catalogFromSnapshot = false;
    _snapshotFingerprint = null;
  }

  bool _started = false;
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

  Future<void> retry({
    Future<List<Channel>> Function()? cacheLoader,
    Future<List<XtreamSeries>> Function()? seriesCacheLoader,
    Future<List<Channel>> Function()? remoteLoader,
    Duration remoteTimeout = const Duration(seconds: 10),
  }) async {
    if (_initialReadyCompleter.isCompleted) {
      _initialReadyCompleter = Completer<void>();
    }
    _started = false;
    _setReadiness(const CatalogReadiness(CatalogLoadPhase.restoringSession));
    await load(
      cacheLoader: cacheLoader,
      seriesCacheLoader: seriesCacheLoader,
      remoteLoader: remoteLoader,
      remoteTimeout: remoteTimeout,
    );
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

  Future<void> load({
    Future<List<Channel>> Function()? cacheLoader,
    Future<List<XtreamSeries>> Function()? seriesCacheLoader,
    Future<List<Channel>> Function()? remoteLoader,
    Duration remoteTimeout = const Duration(seconds: 10),
  }) async {
    error = null;
    if (kIsWeb) _webLiveLoading = true;
    if (kIsWeb) await HourTvWebLivePolicy.instance.load();
    _started = true;
    _lastLoad = DateTime.now();
    _setReadiness(const CatalogReadiness(CatalogLoadPhase.openingCache));

    // Stale-while-revalidate: restaura primero el último resultado parseado.
    // Ninguna petición HTTP forma parte de la ruta del primer render.
    if (all.isEmpty) {
      _legacyLoading = true;
      notifyListeners();
      final cachedChannelsFuture = cacheLoader != null
          ? cacheLoader()
          : StorageService.loadChannels();
      final cachedSeriesFuture = seriesCacheLoader != null
          ? seriesCacheLoader()
          : StorageService.loadSeries();
      final cachedChannels = await cachedChannelsFuture;
      final cachedSeries = await cachedSeriesFuture;
      if (cachedChannels.isNotEmpty || cachedSeries.isNotEmpty) {
        final favorites = StorageService.loadFavorites()
            .map((channel) => channel.url)
            .toSet();
        for (final channel in cachedChannels) {
          channel.isFavorite = favorites.contains(channel.url);
        }
        all = _withoutArchiveMovies(cachedChannels);
        series = cachedSeries;
        _catalogFromSnapshot = cacheLoader == null && seriesCacheLoader == null;
        _snapshotFingerprint = int.tryParse(
          '${StorageService.getSetting(_snapshotFingerprintKey) ?? ''}',
        );
        _recomputeCountries();
      }
    }

    // El catálogo remoto cacheado o el asset local también se leen sin red.
    final localSources = (cacheLoader != null && remoteLoader != null)
        ? const _AssetSources([], [], [], [])
        : await _loadAssetSources();
    if (all.isEmpty && localSources.channels.isNotEmpty) {
      all = _withoutArchiveMovies(localSources.channels);
      _catalogFromSnapshot = false;
    }
    if (series.isEmpty && localSources.series.isNotEmpty) {
      series = localSources.series;
    }
    if (all.isNotEmpty || series.isNotEmpty) {
      _recomputeCountries();
    }
    if (kIsWeb && all.any((channel) => channel.type == MediaType.live)) {
      _webLiveLoading = false;
    }

    _setReadiness(const CatalogReadiness(CatalogLoadPhase.syncingCatalog));

    if (remoteLoader != null) {
      try {
        final remoteChannels = await remoteLoader().timeout(remoteTimeout);
        all = _withoutArchiveMovies(remoteChannels);
        _catalogFromSnapshot = false;
        _recomputeCountries();
        _setReadiness(const CatalogReadiness(CatalogLoadPhase.buildingHome));
        _setReadiness(const CatalogReadiness(CatalogLoadPhase.ready));
        _legacyLoading = false;
        notifyListeners();
      } catch (e) {
        if (all.isNotEmpty || series.isNotEmpty) {
          _setReadiness(
            const CatalogReadiness(
              CatalogLoadPhase.offlineReady,
              message: 'Modo sin conexión',
            ),
          );
        } else {
          _setReadiness(
            CatalogReadiness(
              CatalogLoadPhase.failed,
              message: 'No se pudo cargar el catálogo: $e',
              canRetry: true,
            ),
          );
        }
        _legacyLoading = false;
        notifyListeners();
      }
      if (kIsWeb) {
        _webLiveLoading = false;
        notifyListeners();
      }
      return;
    }

    // En arranque normal: con caché válida o asset local, continúa rápido y revalida de fondo
    if (all.isNotEmpty || series.isNotEmpty) {
      _setReadiness(const CatalogReadiness(CatalogLoadPhase.buildingHome));
      _setReadiness(const CatalogReadiness(CatalogLoadPhase.ready));
      _legacyLoading = false;
      notifyListeners();
      // Con caché visible, la revisión en red (descargas, isolates, huella,
      // EPG/VOD/TMDB) espera a que pasen los primeros segundos: competía en
      // el mismo hilo con el scroll recién abierta la app.
      final isTestEnv =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
      if (isTestEnv) {
        unawaited(_refreshContent(localSources));
      } else {
        unawaited(() async {
          // En web la primera visita no trae canales guardados: esperar 20 s
          // dejaba TV en vivo vacía todo ese rato.
          await Future<void>.delayed(Duration(seconds: kIsWeb ? 3 : 20));
          await _waitForTouchIdle();
          await _refreshContent(localSources);
        }());
      }
    } else {
      // Primera instalación sin fuentes previas: espera la sincronización inicial
      try {
        await _refreshContent(localSources).timeout(remoteTimeout);
        if (all.isNotEmpty || series.isNotEmpty) {
          _setReadiness(const CatalogReadiness(CatalogLoadPhase.buildingHome));
          _setReadiness(const CatalogReadiness(CatalogLoadPhase.ready));
        } else {
          _setReadiness(
            const CatalogReadiness(
              CatalogLoadPhase.failed,
              message: 'No se pudo cargar el catálogo.',
              canRetry: true,
            ),
          );
        }
      } catch (e) {
        if (all.isNotEmpty || series.isNotEmpty) {
          _setReadiness(
            const CatalogReadiness(
              CatalogLoadPhase.offlineReady,
              message: 'Modo sin conexión',
            ),
          );
        } else {
          _setReadiness(
            const CatalogReadiness(
              CatalogLoadPhase.failed,
              message: 'No se pudo cargar el catálogo.',
              canRetry: true,
            ),
          );
        }
      }
    }
    // Cambiar la fila Tendencia mientras se desliza se nota: con la app
    // recién abierta espera a que el usuario suelte la pantalla.
    final isTestEnv =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    unawaited(() async {
      if (!isTestEnv) {
        await _waitForTouchIdle();
      }
      await _refreshTrending();
    }());
  }

  static DateTime _lastPointer = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _pointerRouteInstalled = false;

  /// Espera a que el usuario lleve 1.5 s sin tocar la pantalla, para que el
  /// trabajo de fondo no caiga en medio de un scroll.
  static Future<void> _waitForTouchIdle() async {
    if (!_pointerRouteInstalled) {
      _pointerRouteInstalled = true;
      GestureBinding.instance.pointerRouter.addGlobalRoute(
        (_) => _lastPointer = DateTime.now(),
      );
    }
    for (var i = 0; i < 20; i++) {
      final idle = DateTime.now().difference(_lastPointer);
      if (idle >= const Duration(milliseconds: 1500)) return;
      await Future<void>.delayed(const Duration(milliseconds: 1500) - idle);
    }
  }

  Future<void> _refreshTrending() async {
    final titles = await TmdbService.trendingTitles();
    if (titles.isEmpty || setEquals(titles, _trendingTitles)) return;
    _trendingTitles = titles;
    _trendingCache = null;
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
        debugPrint(
          '[CatalogFetch] Bloqueado por wifiOnly: conectividad=$result',
        );
        return false;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  static const _snapshotFingerprintKey = 'catalogSnapshotFingerprint';

  /// Subir al cambiar cómo se interpreta el catálogo (parser, dedupe,
  /// filtros de `all`): fuerza reconstruir aunque las fuentes no cambien.
  static const _catalogPipelineVersion = 2; // 2: guarda tmdbId (subtítulos)

  /// `all`/`series` son exactamente la caché cuyo origen tiene esta huella.
  bool _catalogFromSnapshot = false;
  int? _snapshotFingerprint;

  /// Huella de todo lo que determina el catálogo final. null = no se puede
  /// asegurar que nada cambió (web, una fuente falló, sin huella del panel):
  /// en ese caso siempre se reconstruye.
  int? _catalogInputFingerprint(
    _AssetSources assetSources,
    List<M3UList> lists,
    List<
      ({M3UList list, List<Channel> channels, bool success, int fingerprint})
    >
    results,
  ) {
    if (kIsWeb || assetSources.fingerprint == null) return null;
    if (results.any((r) => !r.success)) return null;
    return combineFingerprints([
      _catalogPipelineVersion,
      assetSources.fingerprint,
      for (final list in lists) ...[
        list.url,
        list.name,
        list.category,
        list.mediaType,
        list.userAgent,
        list.isStalker,
        list.username,
      ],
      for (final r in results) ...[r.list.url, r.fingerprint],
    ]);
  }

  Future<void> _refreshContent(_AssetSources fallbackSources) async {
    if (_networkLoadRunning) {
      _refreshAgain = true;
      return;
    }
    if (!await _remoteRefreshAllowed()) {
      if (kIsWeb) _webLiveLoading = false;
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
            final fetched = await M3UParserService.fetchAndParseSigned(
              list.url,
              listName: list.name,
              genre: (list.mediaType == 'movie' || list.mediaType == 'series')
                  ? list.name
                  : list.category,
              mediaType: list.mediaType,
              userAgent: list.userAgent,
            );
            return (
              list: list,
              channels: fetched.channels,
              success: true,
              fingerprint: fetched.fingerprint,
            );
          } catch (_) {
            return (
              list: list,
              channels: const <Channel>[],
              success: false,
              fingerprint: 0,
            );
          }
        }),
      );

      // Si todo lo que produce el catálogo es idéntico a lo que generó la
      // caché ya visible, no se reconstruye nada: reasignar `all` invalidaba
      // todas las cachés y reconstruía Inicio entero (~100-150 ms congelado
      // unos segundos después de abrir), para mostrar exactamente lo mismo.
      final inputFingerprint = _catalogInputFingerprint(
        assetSources,
        lists,
        results,
      );
      if (inputFingerprint != null &&
          _catalogFromSnapshot &&
          inputFingerprint == _snapshotFingerprint) {
        debugPrint(
          '[CatalogFetch] Catálogo sin cambios: se conserva el visible',
        );
        _setReadiness(const CatalogReadiness(CatalogLoadPhase.ready));
        _legacyLoading = false;
        unawaited(_loadEpg(assetSources.epgUrls));
        unawaited(_loadVod(lists, assetSources.series, failed));
        unawaited(_enrichMovies(all));
        return;
      }

      final seen = <String>{};
      // El catalogo del panel (assetSources.channels, se agrega primero) ya
      // trae poster/sinopsis de TMDB. Si otra fuente (una lista M3U propia)
      // trae la MISMA pelicula/serie con otra URL, antes convivian como dos
      // tarjetas separadas -una con caratula real, otra con un fotograma al
      // azar-. Dedupe tambien por titulo (solo VOD, En Vivo se deja intacto)
      // para que gane siempre la version del panel.
      final seenVodTitles = <String>{};
      String? vodTitleKey(Channel c) => c.type == MediaType.live
          ? null
          : TmdbService.normalizeTitle(c.displayName);
      final refreshedChannels = <Channel>[];
      for (final channel in assetSources.channels) {
        if (kIsWeb && !HourTvWebLivePolicy.instance.retain(channel)) continue;
        // Las pelis/series del panel se deduplican por su id único, NO por url:
        // dos titulos distintos pueden compartir la misma URL de servidor y una
        // desaparecia. El prefijo evita chocar con las urls de los canales.
        final key = channel.tvgId?.isNotEmpty == true
            ? 'id:${channel.tvgId}'
            : channel.url;
        if (seen.add(key)) {
          refreshedChannels.add(channel);
          final titleKey = vodTitleKey(channel);
          if (titleKey != null && titleKey.isNotEmpty) {
            seenVodTitles.add(titleKey);
          }
        }
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
          if (kIsWeb && !HourTvWebLivePolicy.instance.retain(channel)) continue;
          final titleKey = vodTitleKey(channel);
          if (titleKey != null &&
              titleKey.isNotEmpty &&
              seenVodTitles.contains(titleKey)) {
            continue;
          }
          if (seen.add(channel.url)) {
            refreshedChannels.add(channel);
            if (titleKey != null && titleKey.isNotEmpty) {
              seenVodTitles.add(titleKey);
            }
          }
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
      all = _withoutArchiveMovies(refreshedChannels);
      series = assetSources.series;
      _catalogFromSnapshot = false;
      _recomputeCountries();
      _setReadiness(const CatalogReadiness(CatalogLoadPhase.buildingHome));
      _setReadiness(const CatalogReadiness(CatalogLoadPhase.ready));
      _legacyLoading = false;
      notifyListeners();
      // La huella vieja se borra antes de escribir la caché nueva y se guarda
      // después: si la app muere a mitad, la próxima vez no coincide y se
      // reconstruye (nunca se conserva una caché que no corresponde).
      await StorageService.saveSetting(_snapshotFingerprintKey, null);
      await _persistSnapshot();
      if (inputFingerprint != null) {
        await StorageService.saveSetting(
          _snapshotFingerprintKey,
          inputFingerprint.toString(),
        );
        _snapshotFingerprint = inputFingerprint;
        _catalogFromSnapshot = true;
      }

      unawaited(_loadEpg(assetSources.epgUrls));
      unawaited(_loadVod(lists, assetSources.series, failed));
      unawaited(_enrichMovies(all));
    } catch (exception) {
      debugPrint('[CatalogFetch] _refreshContent falló: $exception');
      if (all.isEmpty && series.isEmpty) {
        error = exception.toString();
        _setReadiness(
          CatalogReadiness(
            CatalogLoadPhase.failed,
            message: error,
            canRetry: true,
          ),
        );
        _legacyLoading = false;
        notifyListeners();
      } else {
        _setReadiness(
          const CatalogReadiness(
            CatalogLoadPhase.offlineReady,
            message: 'Modo sin conexión',
          ),
        );
      }
    } finally {
      failedSourceNames = failed;
      if (kIsWeb) _webLiveLoading = false;
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
    // Mismo criterio que en _refreshContent: si la cuenta Xtream/Stalker del
    // usuario trae una pelicula/serie que el catalogo del panel ya tiene por
    // otra URL, se descarta la copia (sin poster/sinopsis reales) en vez de
    // mostrar las dos.
    final existingVodTitles = {
      for (final c in all)
        if (c.type != MediaType.live) TmdbService.normalizeTitle(c.displayName),
    }..removeWhere((t) => t.isEmpty);
    for (final channel in [...movies, ...stalkerChannels]) {
      if (byUrl.containsKey(channel.url)) continue;
      if (channel.type != MediaType.live &&
          existingVodTitles.contains(
            TmdbService.normalizeTitle(channel.displayName),
          )) {
        continue;
      }
      channel.isFavorite = favorites.contains(channel.url);
      all.add(channel);
      byUrl[channel.url] = channel;
      if (channel.type != MediaType.live) {
        existingVodTitles.add(TmdbService.normalizeTitle(channel.displayName));
      }
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
  static const _enrichAttemptsKey = 'enrichAttemptDay';

  Future<void> _enrichMovies(List<Channel> movies) async {
    // Las que TMDB/Xtream no encontraron se volvían a pedir en CADA arranque
    // (hasta 80 peticiones con TLS en el hilo principal mientras se hace
    // scroll). Se reintentan como mucho una vez por semana.
    final today = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    final rawAttempts = StorageService.getSetting(_enrichAttemptsKey);
    final attempts = <String, int>{
      if (rawAttempts is Map)
        for (final e in rawAttempts.entries)
          if (e.value is int) '${e.key}': e.value as int,
    };
    final needing = movies
        .where(
          (c) =>
              c.type == MediaType.movie &&
              (attempts[c.url] ?? -1000) < today - 7 &&
              [c.plot, c.year, c.rating].any((v) => (v ?? '').trim().isEmpty),
        )
        .take(80)
        .toList();
    if (needing.isEmpty) return;
    for (final movie in needing) {
      attempts[movie.url] = today;
    }
    final pruned = attempts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    unawaited(
      StorageService.saveSetting(_enrichAttemptsKey, {
        for (final e in pruned.take(500)) e.key: e.value,
      }),
    );

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

  /// Solo se muestra lo que entra por el catálogo administrado
  /// (hourtv-adming: panel + scraper automático) o por las fuentes que el
  /// propio usuario agrega. Antes tambien se sumaba solo Internet Archive
  /// como "contenido gratis extra" sin pasar por ahi; se quita el filtro
  /// para que las peliculas que nunca se dieron de alta en el panel no
  /// aparezcan, y limpia las que ya hubieran quedado guardadas de una
  /// version anterior.
  List<Channel> _withoutArchiveMovies(List<Channel> channels) {
    final kept = channels.where((c) => !c.url.startsWith('archive:')).toList();
    return kIsWeb ? HourTvWebLivePolicy.instance.filter(kept) : kept;
  }

  /// Última versión buena del catálogo remoto, disponible sin red.
  Future<String?> _cachedRemoteSources() async {
    final cached = await StorageService.loadRemoteSourcesCache();
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

  /// raw.githubusercontent.com se sirve por una CDN que puede tardar minutos
  /// en propagar un cambio, y de forma desigual por región: dos personas
  /// pueden pedir la misma URL a la vez y recibir contenido distinto. El
  /// panel guarda una copia del catálogo publicado en esta tabla de Supabase
  /// (lectura directa a Postgres, sin caché de CDN) para que lo publicado se
  /// vea al instante. Si no hay Supabase configurado o falla, se sigue con
  /// las URLs de GitHub como hasta ahora.
  Future<String?> _fetchCatalogSnapshotFromSupabase() async {
    if (!SupabaseBootstrap.instance.isAvailable) return null;
    final client = SupabaseBootstrap.instance.client;
    if (client == null) return null;
    try {
      final row = await client
          .from('catalog_snapshot')
          .select('content')
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      final content = row?['content'];
      if (content is String && content.trim().isNotEmpty) {
        debugPrint(
          '[CatalogFetch] OK Supabase catalog_snapshot bytes=${content.length}',
        );
        await StorageService.saveRemoteSourcesCache(content);
        return content;
      }
    } catch (e) {
      debugPrint('[CatalogFetch] Falló Supabase catalog_snapshot: $e');
    }
    return null;
  }

  /// Descarga una nueva versión sin bloquear el primer render.
  Future<String?> _fetchRemoteSourcesFromNetwork() async {
    final configured =
        (StorageService.getSetting('remoteSourcesUrl', defaultValue: '') ?? '')
            .toString()
            .trim();
    // El JSON de GitHub es la publicación canónica del panel. El snapshot de
    // Supabase puede quedarse atrás si una publicación no pudo sincronizarse
    // (por ejemplo, porque el panel no tenía sesión); por eso solo se usa como
    // respaldo, después de intentar las URLs canónicas.
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
        // Descarga (TLS de ~6 MB) y decodificación en un isolate: en el
        // isolate principal comparten hilo con el dibujo y el scroll.
        final result = await compute((_) async {
          final response = await http
              .get(
                fresh,
                // En el navegador esas cabeceras obligan a una consulta CORS
                // previa que GitHub rechaza; el "_=" de la URL ya evita la
                // caché.
                headers: kIsWeb
                    ? null
                    : {
                        'User-Agent': 'Mozilla/5.0',
                        'Cache-Control': 'no-cache',
                      },
              )
              .timeout(const Duration(seconds: 12));
          return (
            status: response.statusCode,
            length: response.bodyBytes.length,
            body: utf8.decode(response.bodyBytes, allowMalformed: true),
          );
        }, null);
        final body = result.body;
        if (result.status == 200 && body.trim().isNotEmpty) {
          debugPrint(
            '[CatalogFetch] OK $url status=${result.status} bytes=${result.length}',
          );
          await StorageService.saveRemoteSourcesCache(body);
          return body;
        }
        debugPrint(
          '[CatalogFetch] Respuesta no válida $url status=${result.status} bodyLen=${result.length}',
        );
      } catch (e) {
        debugPrint('[CatalogFetch] Falló $url: $e');
      }
    }
    // Si el usuario configuró una URL propia, no sustituirla por otra fuente.
    // Para la URL predeterminada del panel, Supabase es un fallback offline
    // adicional cuando GitHub no responde.
    if (configured.isEmpty) {
      return _fetchCatalogSnapshotFromSupabase();
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
      raw ??= await _cachedRemoteSources();
      final isTestEnv =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
      if (raw == null && !kIsWeb) {
        try {
          final file = File('assets/data/sources.json');
          if (isTestEnv) {
            if (file.existsSync()) {
              raw = file.readAsStringSync();
            }
          } else {
            if (await file.exists()) {
              raw = await file.readAsString();
            }
          }
        } catch (_) {}
      }
      if (raw == null) {
        try {
          raw = await rootBundle.loadString('assets/data/sources.json');
        } catch (_) {}
      }
      if (raw == null) return const _AssetSources([], [], [], []);
      final rawForHash = raw;
      var fingerprint = isTestEnv
          ? fingerprintString(rawForHash)
          : await compute(fingerprintString, rawForHash);
      var parsed = isTestEnv
          ? _parseSourcesInIsolate(raw)
          : await compute(_parseSourcesInIsolate, raw);
      if (parsed.series.isEmpty) {
        try {
          String? assetRaw;
          if (!kIsWeb) {
            final file = File('assets/data/sources.json');
            if (isTestEnv) {
              if (file.existsSync()) {
                assetRaw = file.readAsStringSync();
              }
            } else {
              if (await file.exists()) {
                assetRaw = await file.readAsString();
              }
            }
          }
          assetRaw ??= await rootBundle.loadString('assets/data/sources.json');
          final assetParsed = isTestEnv
              ? _parseSourcesInIsolate(assetRaw)
              : await compute(_parseSourcesInIsolate, assetRaw);
          if (assetParsed.series.isNotEmpty) {
            fingerprint = combineFingerprints([
              fingerprint,
              fingerprintString(assetRaw),
            ]);
            parsed = CatalogPayload(
              lists: [...parsed.lists, ...assetParsed.lists],
              epgUrls: [...parsed.epgUrls, ...assetParsed.epgUrls],
              channels: parsed.channels.isNotEmpty
                  ? parsed.channels
                  : assetParsed.channels,
              series: assetParsed.series,
            );
          }
        } catch (_) {}
      }
      return _AssetSources(
        parsed.lists,
        parsed.epgUrls,
        [
          ...parsed.channels,
          if (kIsWeb) ...HourTvWebLivePolicy.instance.channels,
        ],
        parsed.series,
        fingerprint: fingerprint,
      );
    } catch (_) {
      return const _AssetSources([], [], [], []);
    }
  }

  static CatalogPayload _parseSourcesInIsolate(String raw) {
    final payload = CatalogParser.parse(jsonDecode(raw));
    for (final channel in payload.channels) {
      channel.warmDerivedFields();
    }
    return payload;
  }

  // La guía EPG (hasta 24 XML de varios MB y asociarla a todos los canales)
  // solo sirve en En Vivo: se descarga la primera vez que se abre esa
  // pestaña, no en cada arranque compitiendo con el scroll de Inicio.
  List<String> _pendingEpgUrls = const [];
  bool _epgRequested = false;

  /// Lo llama la página de En Vivo al abrirse.
  void ensureEpgLoaded() {
    if (_epgRequested) return;
    _epgRequested = true;
    unawaited(_loadEpg(_pendingEpgUrls));
  }

  Future<void> _loadEpg(List<String> urls) async {
    _pendingEpgUrls = urls;
    if (!_epgRequested) return;
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
  int _visibleAllMode = -1;

  /// Se memoriza porque la UI lee este getter varias veces por build y filtrar
  /// el catalogo completo en cada lectura era lo que trababa el modo
  /// restringido. El cache se invalida si `all` se reemplaza, si le crecen
  /// elementos, o si cambia el estado del control parental.
  List<Channel> get visibleAll {
    final mode = ParentalControlService.filterMode;
    final cached = _visibleAllCache;
    if (cached != null &&
        identical(_visibleAllSource, all) &&
        _visibleAllLength == all.length &&
        _visibleAllMode == mode) {
      return cached;
    }
    final filtered = ParentalControlService.filterChannels(all);
    _visibleAllCache = filtered;
    _visibleAllSource = all;
    _visibleAllLength = all.length;
    _visibleAllMode = mode;
    return filtered;
  }

  List<XtreamSeries>? _visibleSeriesCache;
  List<XtreamSeries>? _visibleSeriesSource;
  int _visibleSeriesLength = -1;
  int _visibleSeriesMode = -1;

  List<XtreamSeries> get visibleSeries {
    final mode = ParentalControlService.filterMode;
    final cached = _visibleSeriesCache;
    if (cached != null &&
        identical(_visibleSeriesSource, series) &&
        _visibleSeriesLength == series.length &&
        _visibleSeriesMode == mode) {
      return cached;
    }
    final filtered = ParentalControlService.filterSeries(series);
    _visibleSeriesCache = filtered;
    _visibleSeriesSource = series;
    _visibleSeriesLength = series.length;
    _visibleSeriesMode = mode;
    return filtered;
  }

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

  Object? _moviesSource;
  List<Channel> _moviesCache = const [];

  // Se lee en cada build de Inicio y de la ficha; filtrar todo visibleAll
  // (miles de canales en vivo) cada vez trababa la UI.
  List<Channel> get movies {
    final all = visibleAll;
    if (!identical(all, _moviesSource)) {
      _moviesSource = all;
      _moviesCache = List.unmodifiable(
        all.where((c) => c.type == MediaType.movie),
      );
    }
    return _moviesCache;
  }

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

  static final _genreSepRe = RegExp(r'[,/|]');
  // Las filas de Inicio clasifican todo el catálogo en cada rebuild y cada
  // vez que llega un catálogo nuevo (objetos Channel nuevos). El resultado
  // depende solo del texto de género/categorías, que se repite muchísimo:
  // se cachea por ese texto y sobrevive a las recargas.
  // ponytail: mapa sin límite, acotado por la cantidad de combinaciones de
  // género distintas del catálogo (cientos).
  static final _genresByText = <String, Set<String>>{};

  Set<String> _genresForMovie(Channel movie) {
    final key = movie.categories.isEmpty
        ? (movie.genre ?? '')
        : '${movie.genre ?? ''}\u0000${movie.categories.join('\u0000')}';
    return _genresByText[key] ??= _computeGenresForMovie(movie);
  }

  Set<String> _computeGenresForMovie(Channel movie) {
    final genres = <String>{};
    final values = <String>[
      if (movie.genre != null) movie.genre!,
      ...movie.categories,
    ];
    for (final value in values) {
      for (final part in value.split(_genreSepRe)) {
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

  final Map<String, List<Channel>> _genreCategoryCache = {};
  List<Channel>? _trendingCache;
  Object? _genreCategorySource;
  int _genreCategoryLength = -1;
  bool _genreCategoryRestricted = false;
  int _trendingTitlesCount = -1;

  void _checkAndInvalidateGenreCache() {
    final restricted = ParentalControlService.isEnabled;
    if (!identical(_genreCategorySource, all) ||
        _genreCategoryLength != all.length ||
        _genreCategoryRestricted != restricted ||
        _trendingTitlesCount != _trendingTitles.length) {
      _genreCategoryCache.clear();
      _trendingCache = null;
      _genreCategorySource = all;
      _genreCategoryLength = all.length;
      _genreCategoryRestricted = restricted;
      _trendingTitlesCount = _trendingTitles.length;
    }
  }

  /// Calcula anime, kDramas y trending en UNA pasada por el catálogo, en
  /// tandas con un frame entre ellas. Antes eran tres recorridos completos de
  /// un tirón (~50 ms cada uno) sobre el mismo hilo que dibuja y recibe el
  /// scroll (Flutter 3.29+ fusiona el hilo de UI con el de Android).
  Future<void> warmHomeGenreRows() async {
    if (homeGenreRowsReady) return;
    final source = visibleAll;
    final sourceAll = all;
    final anime = <Channel>[];
    final kDramas = <Channel>[];
    final byTmdb = <Channel>[];
    final trendingTitlesSnapshot = _trendingTitles;
    // Presupuesto por tiempo, no por cantidad: la primera vez cada título
    // pasa por varias regex y 250 por tanda eran 30-48 ms seguidos.
    final budget = Stopwatch()..start();
    for (var i = 0; i < source.length; i++) {
      final c = source[i];
      if (c.type != MediaType.live) {
        final genres = _genresForMovie(c);
        if (genres.contains('Anime')) anime.add(c);
        if (genres.contains('K-Drama')) kDramas.add(c);
        if (trendingTitlesSnapshot.contains(_normalizedTitle(c.displayName))) {
          byTmdb.add(c);
        }
      }
      if (budget.elapsedMilliseconds >= 6) {
        await SchedulerBinding.instance.endOfFrame;
        if (!identical(all, sourceAll)) return;
        budget.reset();
      }
    }
    _checkAndInvalidateGenreCache();
    if (!identical(_genreCategorySource, sourceAll)) return;
    _genreCategoryCache['Anime'] ??= List.of(anime, growable: false);
    _genreCategoryCache['K-Drama'] ??= List.of(kDramas, growable: false);
    if (_trendingCache == null &&
        identical(_trendingTitles, trendingTitlesSnapshot)) {
      _trendingCache = List.of(byTmdb, growable: false);
    }
  }

  /// Si anime/kDramas/trending ya están calculados para el catálogo actual
  /// (leerlos no recorre el catálogo).
  bool get homeGenreRowsReady {
    _checkAndInvalidateGenreCache();
    return _genreCategoryCache.containsKey('Anime') &&
        _genreCategoryCache.containsKey('K-Drama') &&
        _trendingCache != null;
  }

  List<Channel> _nonLiveByCanonicalGenre(String genre) {
    _checkAndInvalidateGenreCache();
    final cached = _genreCategoryCache[genre];
    if (cached != null) return cached;

    final computed = visibleAll
        .where((c) => c.type != MediaType.live)
        .where((c) => _genresForMovie(c).contains(genre))
        .toList(growable: false);
    _genreCategoryCache[genre] = computed;
    return computed;
  }

  /// Anime y K-Drama pueden venir como película o como serie: a diferencia
  /// de `moviesByGenre` (solo películas), estas dos filas del Inicio buscan
  /// en todo el catálogo VOD.
  List<Channel> get anime => _nonLiveByCanonicalGenre('Anime');

  List<Channel> get kDramas => _nonLiveByCanonicalGenre('K-Drama');

  /// Primero cruza el catálogo contra lo que TMDB marca en tendencia esta
  /// semana (popularidad real, no solo de este dispositivo). Sin coincidencias
  /// no muestra historial local como si fueran tendencias.
  // normalizeTitle usa varias regex; los títulos se repiten entre recargas.
  static final _normalizedTitles = <String, String>{};
  static String _normalizedTitle(String name) =>
      _normalizedTitles[name] ??= TmdbService.normalizeTitle(name);

  List<Channel> get trending {
    _checkAndInvalidateGenreCache();
    if (_trendingCache != null) return _trendingCache!;

    if (_trendingTitles.isNotEmpty) {
      final byTmdb = visibleAll
          .where((c) => c.type != MediaType.live)
          .where(
            (c) => _trendingTitles.contains(_normalizedTitle(c.displayName)),
          )
          .toList(growable: false);
      if (byTmdb.isNotEmpty) {
        _trendingCache = byTmdb;
        return byTmdb;
      }
    }
    const result = <Channel>[];
    _trendingCache = result;
    return result;
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
    // Solo hacen falta los pocos títulos vistos: antes se armaba un mapa con
    // todo `all` (miles de canales en vivo) en cada build de Inicio.
    final wanted = {for (final item in saved) item.url};
    final activeByUrl = <String, Channel>{};
    if (wanted.isNotEmpty) {
      for (final channel in all) {
        if (wanted.contains(channel.url)) activeByUrl[channel.url] = channel;
      }
    }
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
  List<Channel> get continueWatching {
    final seen = <String>{};
    final result = <Channel>[];
    // History is newest first. Claim the series before filtering progress:
    // finishing its latest episode must not revive an older unfinished one.
    for (final item in history) {
      if (item.type == MediaType.live) continue;
      var key = 'video:${item.url}';
      if (item.type == MediaType.series) {
        final id = item.tvgId ?? '';
        for (final parent in series) {
          if ((id.isNotEmpty && id.startsWith('${parent.seriesId}:')) ||
              (parent.episodes ?? const <Channel>[]).any(
                (episode) => item.url.isNotEmpty && episode.url == item.url,
              )) {
            key = 'series:${parent.seriesId}';
            break;
          }
        }
        if (key.startsWith('video:') && id.startsWith('catalog:')) {
          final match = RegExp(r'^(.*):\d+:\d+$').firstMatch(id);
          if (match != null) key = 'series:${match.group(1)}';
        }
      }
      if (!seen.add(key)) continue;
      final fraction = item.progressFraction;
      if (fraction != null && fraction > 0.02 && fraction < 0.95) {
        result.add(item);
      }
    }
    return result;
  }

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

  /// Huella del/los JSON crudos de los que salió (null si no se conoce).
  final int? fingerprint;
  const _AssetSources(
    this.lists,
    this.epgUrls,
    this.channels,
    this.series, {
    this.fingerprint,
  });

  bool get isEmpty =>
      lists.isEmpty && epgUrls.isEmpty && channels.isEmpty && series.isEmpty;
}
