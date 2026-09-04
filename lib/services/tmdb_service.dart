import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

/// Enriquecimiento con The Movie Database (TMDB): sinopsis, año, rating,
/// reparto, director y backdrop para CUALQUIER película (M3U, Xtream o
/// Archive), buscando por título. Idea tomada de IPTVnator (MIT).
///
/// Como En Vivo/Pluto TV: funciona solo, sin pedirle ninguna clave al
/// usuario. La API key es de la app (gratuita en themoviedb.org, cuenta de
/// HourTV), no un ajuste que cada quien tenga que configurar.
class TmdbService {
  static const _base = 'https://api.themoviedb.org/3';
  static const _img = 'https://image.tmdb.org/t/p';

  /// API key v3 de themoviedb.org.
  static const _key = '4e7c09672d1c817a7dc6150d9dd25aa2';

  /// Cache por URL de canal: comparte el Future para no repetir peticiones.
  static final Map<String, Future<bool>> _cache = {};

  static bool get enabled => _key.isNotEmpty;

  /// Completa los campos vacíos de [ch] con datos de TMDB. Devuelve true si
  /// cambió algo. Seguro de llamar repetidamente (cachea por URL).
  static Future<bool> enrich(Channel ch) {
    if (!enabled || ch.type == MediaType.live) return Future.value(false);
    return _cache.putIfAbsent(ch.url, () => _enrich(ch));
  }

  static Set<String>? _trendingCache;
  static DateTime? _trendingCacheAt;

  /// Títulos (normalizados) que TMDB marca en tendencia esta semana, para
  /// cruzarlos contra el catálogo propio en la fila "Tendencia" del Inicio:
  /// así "en tendencia" refleja popularidad real, no solo lo que este
  /// perfil ya vio. Cacheado 12h en memoria para no golpear la API en cada
  /// carga del catálogo.
  static Future<Set<String>> trendingTitles() async {
    if (!enabled) return {};
    final cached = _trendingCache;
    final cachedAt = _trendingCacheAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(hours: 12)) {
      return cached;
    }
    try {
      final res = await http
          .get(Uri.parse('$_base/trending/all/week?api_key=$_key'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return cached ?? {};
      final results = (jsonDecode(res.body)['results'] as List?) ?? [];
      final titles = <String>{
        for (final item in results.whereType<Map>())
          normalizeTitle((item['title'] ?? item['name'] ?? '').toString()),
      }..removeWhere((title) => title.isEmpty);
      _trendingCache = titles;
      _trendingCacheAt = DateTime.now();
      return titles;
    } catch (_) {
      return cached ?? {};
    }
  }

  /// Comparacion tolerante a mayusculas, acentos y puntuacion: los titulos
  /// de fuentes IPTV rara vez coinciden letra por letra con TMDB.
  static String normalizeTitle(String value) {
    const accents = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n',
    };
    var result = value.trim().toLowerCase();
    accents.forEach((accented, plain) => result = result.replaceAll(accented, plain));
    return result
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<bool> _enrich(Channel ch) async {
    try {
      final query = Uri.encodeQueryComponent(ch.displayName);
      final yearHint = int.tryParse(ch.year?.trim() ?? '');
      final url =
          '$_base/search/movie?api_key=$_key&language=es-ES&query=$query'
          '${yearHint != null ? '&year=$yearHint' : ''}';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return false;
      final results = (jsonDecode(res.body)['results'] as List?) ?? [];
      if (results.isEmpty) return false;
      final m = results.first as Map;

      var changed = false;
      void fill(String? current, dynamic value, void Function(String) set) {
        final v = (value ?? '').toString().trim();
        if ((current == null || current.trim().isEmpty) && v.isNotEmpty) {
          set(v);
          changed = true;
        }
      }

      fill(ch.plot, m['overview'], (v) => ch.plot = v);
      fill(ch.year, (m['release_date'] ?? '').toString().split('-').first,
          (v) => ch.year = v);
      final vote = (m['vote_average'] as num?)?.toDouble();
      if ((ch.rating == null || ch.rating!.trim().isEmpty) &&
          vote != null &&
          vote > 0) {
        ch.rating = vote.toStringAsFixed(1);
        changed = true;
      }
      fill(ch.backdrop, m['backdrop_path'] != null ? '$_img/w1280${m['backdrop_path']}' : null,
          (v) => ch.backdrop = v);

      // Reparto y director (segunda llamada, solo si faltan)
      final id = m['id'];
      if (id != null &&
          ((ch.cast == null || ch.cast!.isEmpty) ||
              (ch.director == null || ch.director!.isEmpty))) {
        try {
          final credRes = await http
              .get(Uri.parse('$_base/movie/$id/credits?api_key=$_key'))
              .timeout(const Duration(seconds: 12));
          if (credRes.statusCode == 200) {
            final data = jsonDecode(credRes.body) as Map;
            final castList = (data['cast'] as List?) ?? [];
            final crew = (data['crew'] as List?) ?? [];
            final actors = castList
                .take(10)
                .map((c) => (c as Map)['name']?.toString() ?? '')
                .where((n) => n.isNotEmpty)
                .join(', ');
            final directors = crew
                .where((c) => (c as Map)['job'] == 'Director')
                .map((c) => (c as Map)['name']?.toString() ?? '')
                .where((n) => n.isNotEmpty)
                .join(', ');
            fill(ch.cast, actors, (v) => ch.cast = v);
            fill(ch.director, directors, (v) => ch.director = v);
          }
        } catch (_) {}
      }
      return changed;
    } catch (_) {
      return false;
    }
  }
}
