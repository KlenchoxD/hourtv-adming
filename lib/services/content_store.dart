import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/channel.dart';
import '../models/m3u_list.dart';
import 'storage_service.dart';
import 'm3u_parser_service.dart';
import 'xtream_service.dart';
import 'archive_service.dart';
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

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
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
        byUrl[l.url] = l;
      }
      lists = byUrl.values.toList();

      final results = await Future.wait(
        lists.map(
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
      _recomputeCountries();
      loading = false;
      notifyListeners();

      _loadEpg(assetSources.epgUrls); // guia EPG/XMLTV, en segundo plano
      _loadVod(
        lists,
      ); // peliculas y series desde la API Xtream, en segundo plano
      _loadArchive(); // peliculas de dominio publico (Internet Archive)
    } catch (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadVod(List<M3UList> lists) async {
    final accounts = lists.where((l) => l.isXtream).toList();
    if (accounts.isEmpty) return;
    vodLoading = true;
    notifyListeners();
    final movies = <Channel>[];
    final ser = <XtreamSeries>[];
    for (final a in accounts) {
      try {
        movies.addAll(
          await XtreamService.fetchMovies(a.host!, a.username!, a.password!),
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
    final seen = all.map((c) => c.url).toSet();
    for (final m in movies) {
      if (seen.add(m.url)) all.add(m);
    }
    series = ser;
    vodLoading = false;
    _recomputeCountries();
    notifyListeners();
  }

  /// Lee las fuentes que el usuario agrega desde el script de PC
  /// (assets/data/sources.json). Formato: lista de objetos con
  /// { name, url, type: live|movie|series|xtream, host, username, password }.
  Future<_AssetSources> _loadAssetSources() async {
    try {
      final raw = await rootBundle.loadString('assets/data/sources.json');
      final data = jsonDecode(raw);
      if (data is! List) return const _AssetSources([], []);
      final out = <M3UList>[];
      final epgUrls = <String>[];
      for (final e in data) {
        if (e is! Map) continue;
        final name = (e['name'] ?? 'Fuente').toString();
        final type = (e['type'] ?? 'live').toString().toLowerCase();
        if (type == 'xtream') {
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
          final mt =
              (type == 'movie' || type == 'movies' || type == 'peliculas')
              ? 'movie'
              : (type == 'series' ? 'series' : null);
          final category = (e['category'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final ua = (e['userAgent'] ?? e['user_agent'] ?? '').toString().trim();
          out.add(
            M3UList(
              name: name,
              url: url,
              category: category.isNotEmpty
                  ? category
                  : (mt == null
                        ? 'live'
                        : (mt == 'movie' ? 'peliculas' : 'series')),
              mediaType: mt,
              userAgent: ua.isEmpty ? null : ua,
            ),
          );
        }
      }
      return _AssetSources(out, epgUrls);
    } catch (_) {
      return const _AssetSources([], []);
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

  /// Géneros de película en orden de aparición (para las filas de Inicio).
  List<String> get movieGenres {
    final seen = <String>{};
    final out = <String>[];
    for (final m in movies) {
      final g = m.genre ?? 'Películas';
      if (seen.add(g)) out.add(g);
    }
    return out;
  }

  List<Channel> moviesByGenre(String g) =>
      movies.where((m) => (m.genre ?? 'Películas') == g).toList();
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
  const _AssetSources(this.lists, this.epgUrls);
}
