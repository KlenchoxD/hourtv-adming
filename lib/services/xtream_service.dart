import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

/// Una serie del catalogo Xtream (con su caratula). Los episodios se piden
/// aparte (bajo demanda) con [XtreamService.fetchEpisodes], usando las
/// credenciales de la cuenta de la que vino esta serie.
class XtreamSeries {
  final String seriesId;
  final String name;
  final String? cover;
  final String? plot;
  final String host;
  final String username;
  final String password;
  XtreamSeries({
    required this.seriesId,
    required this.name,
    this.cover,
    this.plot,
    required this.host,
    required this.username,
    required this.password,
  });
}

/// Resultado de validar una cuenta Xtream Codes.
class XtreamAccount {
  final bool authenticated;
  final String message;
  final String? expDate; // fecha de expiracion legible (puede ser null/ilimitada)
  final int? activeConnections;
  final int? maxConnections;

  XtreamAccount({
    required this.authenticated,
    required this.message,
    this.expDate,
    this.activeConnections,
    this.maxConnections,
  });
}

/// Cliente para paneles Xtream Codes (el backend tipo MagisTV).
/// Construye la URL M3U "m3u_plus" (que entrega EN VIVO + PELICULAS + SERIES
/// en un solo archivo, reutilizable por el parser M3U existente) y valida
/// credenciales contra player_api.php.
class XtreamService {
  /// Normaliza el host: asegura esquema http://, sin barra final.
  static String normalizeHost(String host) {
    var h = host.trim();
    if (h.isEmpty) return h;
    if (!h.startsWith('http://') && !h.startsWith('https://')) {
      h = 'http://$h';
    }
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  /// URL M3U con todo el contenido del proveedor (live + VOD + series).
  static String buildM3uUrl(String host, String username, String password) {
    final h = normalizeHost(host);
    final u = Uri.encodeQueryComponent(username.trim());
    final p = Uri.encodeQueryComponent(password.trim());
    return '$h/get.php?username=$u&password=$p&type=m3u_plus&output=ts';
  }

  /// Valida las credenciales y devuelve informacion de la cuenta.
  static Future<XtreamAccount> validate(String host, String username, String password) async {
    final h = normalizeHost(host);
    final u = Uri.encodeQueryComponent(username.trim());
    final p = Uri.encodeQueryComponent(password.trim());
    final url = '$h/player_api.php?username=$u&password=$p';
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        return XtreamAccount(authenticated: false, message: 'El servidor respondió ${res.statusCode}. Revisa el servidor y el puerto.');
      }
      dynamic data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        return XtreamAccount(authenticated: false, message: 'El servidor no respondió en formato Xtream.\nRevisa que el servidor y el PUERTO sean correctos (ej: http://host:8080).');
      }
      final info = data is Map ? data['user_info'] : null;
      if (info == null) {
        return XtreamAccount(authenticated: false, message: 'Respuesta no válida. ¿El servidor es un panel Xtream?');
      }
      final auth = info['auth'] == 1 || info['auth'] == '1';
      final status = (info['status'] ?? '').toString();
      if (!auth || status.toLowerCase() != 'active') {
        return XtreamAccount(authenticated: false, message: 'Usuario o contraseña incorrectos (estado: $status)');
      }
      String? exp;
      final expRaw = info['exp_date'];
      if (expRaw != null && expRaw.toString().isNotEmpty && expRaw.toString() != 'null') {
        final secs = int.tryParse(expRaw.toString());
        if (secs != null) {
          final d = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
          exp = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        }
      } else {
        exp = 'Ilimitada';
      }
      return XtreamAccount(
        authenticated: true,
        message: 'Cuenta activa',
        expDate: exp,
        activeConnections: int.tryParse((info['active_cons'] ?? '').toString()),
        maxConnections: int.tryParse((info['max_connections'] ?? '').toString()),
      );
    } on TimeoutException {
      return XtreamAccount(authenticated: false, message: 'El servidor tardó demasiado en responder.\nPuede estar caído o el puerto ser incorrecto.');
    } catch (e) {
      return XtreamAccount(authenticated: false, message: 'No se pudo conectar.\nVerifica el servidor y el PUERTO (ej: http://host:8080) y tu internet.');
    }
  }

  // -------- API de catalogo (player_api.php con acciones) --------

  static Future<dynamic> _api(String host, String user, String pass, String action, {String extra = ''}) async {
    final h = normalizeHost(host);
    final u = Uri.encodeQueryComponent(user.trim());
    final p = Uri.encodeQueryComponent(pass.trim());
    final url = '$h/player_api.php?username=$u&password=$p&action=$action$extra';
    final res = await http
        .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;
    if (res.body.trim().isEmpty) return null;
    return jsonDecode(res.body);
  }

  /// Peliculas (VOD). Devuelve Channels con URL .../movie/... (tipo pelicula).
  static Future<List<Channel>> fetchMovies(String host, String user, String pass) async {
    final h = normalizeHost(host);
    final u = user.trim();
    final p = pass.trim();
    final data = await _api(h, u, p, 'get_vod_streams');
    if (data is! List) return [];
    final out = <Channel>[];
    for (final m in data) {
      if (m is! Map) continue;
      final id = m['stream_id'];
      if (id == null) continue;
      final ext = (m['container_extension'] ?? 'mp4').toString();
      final icon = (m['stream_icon'] ?? '').toString();
      out.add(Channel(
        name: (m['name'] ?? 'Película').toString(),
        url: '$h/movie/$u/$p/$id.$ext',
        logo: icon.isEmpty ? null : icon,
        category: 'peliculas',
        group: (m['category_id'] ?? '').toString(),
      ));
    }
    return out;
  }

  /// Lista de series (solo metadatos + caratula; los episodios se piden aparte).
  static Future<List<XtreamSeries>> fetchSeriesList(String host, String user, String pass) async {
    final data = await _api(host, user, pass, 'get_series');
    if (data is! List) return [];
    final out = <XtreamSeries>[];
    for (final s in data) {
      if (s is! Map) continue;
      final id = (s['series_id'] ?? '').toString();
      if (id.isEmpty) continue;
      final cover = (s['cover'] ?? '').toString();
      out.add(XtreamSeries(
        seriesId: id,
        name: (s['name'] ?? 'Serie').toString(),
        cover: cover.isEmpty ? null : cover,
        plot: (s['plot'] ?? '').toString(),
        host: host,
        username: user,
        password: pass,
      ));
    }
    return out;
  }

  /// Episodios de una serie (URL .../series/...).
  static Future<List<Channel>> fetchEpisodes(String host, String user, String pass, String seriesId) async {
    final h = normalizeHost(host);
    final u = user.trim();
    final p = pass.trim();
    final data = await _api(h, u, p, 'get_series_info', extra: '&series_id=$seriesId');
    if (data is! Map) return [];
    final eps = data['episodes'];
    final out = <Channel>[];
    if (eps is Map) {
      final seasons = eps.keys.toList()..sort((a, b) => (int.tryParse(a.toString()) ?? 0).compareTo(int.tryParse(b.toString()) ?? 0));
      for (final season in seasons) {
        final list = eps[season];
        if (list is! List) continue;
        for (final e in list) {
          if (e is! Map) continue;
          final id = e['id'];
          if (id == null) continue;
          final ext = (e['container_extension'] ?? 'mp4').toString();
          final title = (e['title'] ?? 'Episodio').toString();
          out.add(Channel(
            name: title,
            url: '$h/series/$u/$p/$id.$ext',
            category: 'series',
            group: 'T$season',
          ));
        }
      }
    }
    return out;
  }
}
