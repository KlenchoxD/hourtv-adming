import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/epg_program.dart';

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
  final List<Channel>? episodes;
  final String? year;
  final String? rating;
  final String? duration;
  final String? genre;
  final String? cast;
  final String? director;
  final String? writer;
  final String? releaseDate;
  final String? backdrop;
  final List<String> categories;
  final bool isFeatured;
  XtreamSeries({
    required this.seriesId,
    required this.name,
    this.cover,
    this.plot,
    required this.host,
    required this.username,
    required this.password,
    this.episodes,
    this.year,
    this.rating,
    this.duration,
    this.genre,
    this.cast,
    this.director,
    this.writer,
    this.releaseDate,
    this.backdrop,
    this.categories = const [],
    this.isFeatured = false,
  });

  Map<String, dynamic> toJson() => {
    'seriesId': seriesId,
    'name': name,
    'cover': cover,
    'plot': plot,
    'host': host,
    'username': username,
    'password': password,
    'episodes': episodes?.map((episode) => episode.toJson()).toList(),
    'year': year,
    'rating': rating,
    'duration': duration,
    'genre': genre,
    'cast': cast,
    'director': director,
    'writer': writer,
    'releaseDate': releaseDate,
    'backdrop': backdrop,
    'categories': categories,
    'isFeatured': isFeatured,
  };

  factory XtreamSeries.fromJson(Map<String, dynamic> json) => XtreamSeries(
    seriesId: json['seriesId']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    cover: json['cover']?.toString(),
    plot: json['plot']?.toString(),
    host: json['host']?.toString() ?? '',
    username: json['username']?.toString() ?? '',
    password: json['password']?.toString() ?? '',
    episodes: (json['episodes'] as List<dynamic>?)
        ?.whereType<Map>()
        .map((episode) => Channel.fromJson(Map<String, dynamic>.from(episode)))
        .toList(),
    year: json['year']?.toString(),
    rating: json['rating']?.toString(),
    duration: json['duration']?.toString(),
    genre: json['genre']?.toString(),
    cast: json['cast']?.toString(),
    director: json['director']?.toString(),
    writer: json['writer']?.toString(),
    releaseDate: (json['releaseDate'] ?? json['release_date'])?.toString(),
    backdrop: json['backdrop']?.toString(),
    categories: (json['categories'] as List<dynamic>? ?? const [])
        .map((category) => category.toString())
        .where((category) => category.isNotEmpty)
        .toList(),
    isFeatured: json['isFeatured'] == true || json['featured'] == true,
  );
}

/// Resultado de validar una cuenta Xtream Codes.
class XtreamAccount {
  final bool authenticated;
  final String message;
  final String?
  expDate; // fecha de expiracion legible (puede ser null/ilimitada)
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

class _VodMetadata {
  final String? plot;
  final String? year;
  final String? rating;
  final String? duration;

  const _VodMetadata({this.plot, this.year, this.rating, this.duration});
}

/// Cliente para paneles Xtream Codes (el backend tipo MagisTV).
/// Construye la URL M3U "m3u_plus" (que entrega EN VIVO + PELICULAS + SERIES
/// en un solo archivo, reutilizable por el parser M3U existente) y valida
/// credenciales contra player_api.php.
class XtreamService {
  static final Map<String, Future<_VodMetadata?>> _vodMetadataCache = {};

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
  static Future<XtreamAccount> validate(
    String host,
    String username,
    String password,
  ) async {
    final h = normalizeHost(host);
    final u = Uri.encodeQueryComponent(username.trim());
    final p = Uri.encodeQueryComponent(password.trim());
    final url = '$h/player_api.php?username=$u&password=$p';
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        return XtreamAccount(
          authenticated: false,
          message:
              'El servidor respondió ${res.statusCode}. Revisa el servidor y el puerto.',
        );
      }
      dynamic data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        return XtreamAccount(
          authenticated: false,
          message:
              'El servidor no respondió en formato Xtream.\nRevisa que el servidor y el PUERTO sean correctos (ej: http://host:8080).',
        );
      }
      final info = data is Map ? data['user_info'] : null;
      if (info == null) {
        return XtreamAccount(
          authenticated: false,
          message: 'Respuesta no válida. ¿El servidor es un panel Xtream?',
        );
      }
      final auth = info['auth'] == 1 || info['auth'] == '1';
      final status = (info['status'] ?? '').toString();
      if (!auth || status.toLowerCase() != 'active') {
        return XtreamAccount(
          authenticated: false,
          message: 'Usuario o contraseña incorrectos (estado: $status)',
        );
      }
      String? exp;
      final expRaw = info['exp_date'];
      if (expRaw != null &&
          expRaw.toString().isNotEmpty &&
          expRaw.toString() != 'null') {
        final secs = int.tryParse(expRaw.toString());
        if (secs != null) {
          final d = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
          exp =
              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        }
      } else {
        exp = 'Ilimitada';
      }
      return XtreamAccount(
        authenticated: true,
        message: 'Cuenta activa',
        expDate: exp,
        activeConnections: int.tryParse((info['active_cons'] ?? '').toString()),
        maxConnections: int.tryParse(
          (info['max_connections'] ?? '').toString(),
        ),
      );
    } on TimeoutException {
      return XtreamAccount(
        authenticated: false,
        message:
            'El servidor tardó demasiado en responder.\nPuede estar caído o el puerto ser incorrecto.',
      );
    } catch (e) {
      return XtreamAccount(
        authenticated: false,
        message:
            'No se pudo conectar.\nVerifica el servidor y el PUERTO (ej: http://host:8080) y tu internet.',
      );
    }
  }

  // -------- API de catalogo (player_api.php con acciones) --------

  static Future<dynamic> _api(
    String host,
    String user,
    String pass,
    String action, {
    String extra = '',
  }) async {
    final h = normalizeHost(host);
    final u = Uri.encodeQueryComponent(user.trim());
    final p = Uri.encodeQueryComponent(pass.trim());
    final url =
        '$h/player_api.php?username=$u&password=$p&action=$action$extra';
    final res = await http
        .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;
    if (res.body.trim().isEmpty) return null;
    return jsonDecode(res.body);
  }

  /// Completa metadata VOD solo cuando una película enfocada la necesita.
  /// Las solicitudes y sus resultados se comparten por URL durante la sesión.
  static Future<bool> enrichMovieMetadata(Channel channel) async {
    final target = _vodTarget(channel.url);
    if (target == null) return false;

    final needsMetadata = [
      channel.plot,
      channel.year,
      channel.rating,
      channel.duration,
    ].any(_isBlank);
    if (!needsMetadata) return false;

    final metadata = await _vodMetadataCache.putIfAbsent(
      channel.url,
      () => _fetchVodMetadata(target),
    );
    if (metadata == null) return false;

    var changed = false;
    if (_isBlank(channel.plot) && !_isBlank(metadata.plot)) {
      channel.plot = metadata.plot;
      changed = true;
    }
    if (_isBlank(channel.year) && !_isBlank(metadata.year)) {
      channel.year = metadata.year;
      changed = true;
    }
    if (_isBlank(channel.rating) && !_isBlank(metadata.rating)) {
      channel.rating = metadata.rating;
      changed = true;
    }
    if (_isBlank(channel.duration) && !_isBlank(metadata.duration)) {
      channel.duration = metadata.duration;
      changed = true;
    }
    return changed;
  }

  static Future<_VodMetadata?> _fetchVodMetadata(
    ({String host, String user, String pass, String vodId}) target,
  ) async {
    try {
      final data = await _api(
        target.host,
        target.user,
        target.pass,
        'get_vod_info',
        extra: '&vod_id=${Uri.encodeQueryComponent(target.vodId)}',
      );
      if (data is! Map) return null;

      final combined = <String, dynamic>{};
      void addSource(dynamic source) {
        if (source is! Map) return;
        for (final entry in source.entries) {
          combined[entry.key.toString()] = entry.value;
        }
      }

      addSource(data['movie_data']);
      addSource(data);
      addSource(data['info']);

      return _VodMetadata(
        plot: _cleanText(combined['plot'] ?? combined['description']),
        year: _yearText(
          combined['year'] ??
              combined['releasedate'] ??
              combined['releaseDate'],
        ),
        rating: _ratingText(combined['rating'] ?? combined['rating_5based']),
        duration: _durationText(combined),
      );
    } catch (_) {
      return null;
    }
  }

  static ({String host, String user, String pass, String vodId})? _vodTarget(
    String url,
  ) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return null;
    final segments = uri.pathSegments;
    final marker = segments.lastIndexOf('movie');
    if (marker < 0 || marker + 3 >= segments.length) return null;

    final file = segments[marker + 3];
    final dot = file.lastIndexOf('.');
    final vodId = dot > 0 ? file.substring(0, dot) : file;
    if (vodId.isEmpty) return null;

    final prefix = segments.take(marker).join('/');
    final host = normalizeHost(
      uri
          .replace(
            path: prefix.isEmpty ? '' : '/$prefix',
            query: null,
            fragment: null,
          )
          .toString(),
    );
    return (
      host: host,
      user: segments[marker + 1],
      pass: segments[marker + 2],
      vodId: vodId,
    );
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static String? _cleanText(dynamic value) {
    if (value is List) value = value.isEmpty ? null : value.first;
    if (value == null || value is Map) return null;
    final text = value
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static String? _yearText(dynamic value) {
    final text = _cleanText(value);
    if (text == null) return null;
    return RegExp(r'(?:19|20)\d{2}').firstMatch(text)?.group(0) ?? text;
  }

  static String? _ratingText(dynamic value) {
    final text = _cleanText(value);
    if (text == null || text == '0' || text == '0.0') return null;
    return text;
  }

  static String? _durationText(Map<dynamic, dynamic> data) {
    final raw = _cleanText(data['duration']);
    if (raw != null && raw != '0') {
      final parts = raw.split(':').map(int.tryParse).toList();
      if (parts.length >= 2 && parts.every((part) => part != null)) {
        final hours = parts.length == 3 ? parts[0]! : 0;
        final minutes = parts.length == 3 ? parts[1]! : parts[0]!;
        return hours > 0 ? '$hours h $minutes min' : '$minutes min';
      }
      return raw;
    }

    final seconds = int.tryParse(
      (data['duration_secs'] ?? data['duration_seconds'] ?? '').toString(),
    );
    if (seconds == null || seconds <= 0) return null;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '$hours h $minutes min' : '$minutes min';
  }

  /// Canales en vivo con el indicador tv_archive que habilita catch-up.
  static Future<List<Channel>> fetchLiveStreams(
    String host,
    String user,
    String pass, {
    String? userAgent,
  }) async {
    final h = normalizeHost(host);
    final u = user.trim();
    final p = pass.trim();
    final data = await _api(h, u, p, 'get_live_streams');
    if (data is! List) return [];
    final out = <Channel>[];
    for (final item in data) {
      if (item is! Map) continue;
      final id = item['stream_id'];
      if (id == null) continue;
      final ext = (item['container_extension'] ?? 'ts').toString();
      final icon = (item['stream_icon'] ?? '').toString();
      final archive = item['tv_archive'];
      out.add(
        Channel(
          name: (item['name'] ?? 'Canal').toString(),
          url: '$h/live/$u/$p/$id.$ext',
          logo: icon.isEmpty ? null : icon,
          group: (item['category_id'] ?? '').toString(),
          category: 'live',
          userAgent: userAgent,
          hasCatchup: archive == 1 || archive == '1' || archive == true,
        ),
      );
    }
    return out;
  }

  /// Construye la URL Xtream timeshift para un programa ya emitido.
  static String? buildTimeshiftUrl(Channel channel, EpgProgram program) {
    if (!channel.hasCatchup || !program.stop.isBefore(DateTime.now())) {
      return null;
    }
    final target = _liveTarget(channel.url);
    if (target == null) return null;
    final seconds = program.stop.difference(program.start).inSeconds;
    if (seconds <= 0) return null;
    final durationMinutes = (seconds + 59) ~/ 60;
    final start = program.start.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final startText =
        '${start.year}-${two(start.month)}-${two(start.day)}:'
        '${two(start.hour)}-${two(start.minute)}';
    final u = Uri.encodeComponent(target.user);
    final p = Uri.encodeComponent(target.pass);
    final id = Uri.encodeComponent(target.streamId);
    return '${target.host}/timeshift/$u/$p/$durationMinutes/$startText/$id.ts';
  }

  static ({String host, String user, String pass, String streamId})?
  _liveTarget(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return null;
    final segments = uri.pathSegments;
    final marker = segments.lastIndexOf('live');
    if (marker < 0 || marker + 3 >= segments.length) return null;
    final file = segments[marker + 3];
    final dot = file.lastIndexOf('.');
    final streamId = dot > 0 ? file.substring(0, dot) : file;
    if (streamId.isEmpty) return null;
    final prefix = segments.take(marker).join('/');
    final host = normalizeHost(
      uri
          .replace(
            path: prefix.isEmpty ? '' : '/$prefix',
            query: null,
            fragment: null,
          )
          .toString(),
    );
    return (
      host: host,
      user: segments[marker + 1],
      pass: segments[marker + 2],
      streamId: streamId,
    );
  }

  /// Peliculas (VOD). Devuelve Channels con URL .../movie/... (tipo pelicula).
  static Future<List<Channel>> fetchMovies(
    String host,
    String user,
    String pass,
  ) async {
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
      out.add(
        Channel(
          name: (m['name'] ?? 'Película').toString(),
          url: '$h/movie/$u/$p/$id.$ext',
          logo: icon.isEmpty ? null : icon,
          category: 'peliculas',
          group: (m['category_id'] ?? '').toString(),
          plot: _cleanText(m['plot'] ?? m['description']),
          year: _yearText(m['year'] ?? m['releasedate'] ?? m['releaseDate']),
          rating: _ratingText(m['rating'] ?? m['rating_5based']),
          duration: _durationText(m),
          cast: _cleanText(m['cast']),
          director: _cleanText(m['director']),
          writer: _cleanText(m['writer'] ?? m['screenwriter']),
          releaseDate: _cleanText(
            m['releasedate'] ?? m['releaseDate'] ?? m['release_date'],
          ),
        ),
      );
    }
    return out;
  }

  /// Lista de series (solo metadatos + caratula; los episodios se piden aparte).
  static Future<List<XtreamSeries>> fetchSeriesList(
    String host,
    String user,
    String pass,
  ) async {
    final data = await _api(host, user, pass, 'get_series');
    if (data is! List) return [];
    final out = <XtreamSeries>[];
    for (final s in data) {
      if (s is! Map) continue;
      final id = (s['series_id'] ?? '').toString();
      if (id.isEmpty) continue;
      final cover = (s['cover'] ?? '').toString();
      out.add(
        XtreamSeries(
          seriesId: id,
          name: (s['name'] ?? 'Serie').toString(),
          cover: cover.isEmpty ? null : cover,
          plot: (s['plot'] ?? '').toString(),
          host: host,
          username: user,
          password: pass,
          year: _yearText(s['year'] ?? s['releaseDate']),
          rating: _ratingText(s['rating'] ?? s['rating_5based']),
          duration: _durationText(s),
          genre: _cleanText(s['genre']),
          cast: _cleanText(s['cast']),
          director: _cleanText(s['director']),
          writer: _cleanText(s['writer'] ?? s['screenwriter']),
          releaseDate: _cleanText(
            s['releaseDate'] ?? s['release_date'] ?? s['releasedate'],
          ),
        ),
      );
    }
    return out;
  }

  /// Episodios de una serie (URL .../series/...).
  static Future<List<Channel>> fetchEpisodes(
    String host,
    String user,
    String pass,
    String seriesId,
  ) async {
    final h = normalizeHost(host);
    final u = user.trim();
    final p = pass.trim();
    final data = await _api(
      h,
      u,
      p,
      'get_series_info',
      extra: '&series_id=$seriesId',
    );
    if (data is! Map) return [];
    final eps = data['episodes'];
    final out = <Channel>[];
    if (eps is Map) {
      final seasons = eps.keys.toList()
        ..sort(
          (a, b) => (int.tryParse(a.toString()) ?? 0).compareTo(
            int.tryParse(b.toString()) ?? 0,
          ),
        );
      for (final season in seasons) {
        final list = eps[season];
        if (list is! List) continue;
        for (final e in list) {
          if (e is! Map) continue;
          final id = e['id'];
          if (id == null) continue;
          final ext = (e['container_extension'] ?? 'mp4').toString();
          final title = (e['title'] ?? 'Episodio').toString();
          out.add(
            Channel(
              name: title,
              url: '$h/series/$u/$p/$id.$ext',
              category: 'series',
              group: 'T$season',
            ),
          );
        }
      }
    }
    return out;
  }
}
