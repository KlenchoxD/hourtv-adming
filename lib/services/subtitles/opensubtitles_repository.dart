import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'hourtv_subtitle_track.dart';

/// Proveedor de subtítulos oficial de OpenSubtitles.com (API v1).
///
/// Características de seguridad y resiliencia:
/// - Lectura segura de la clave vía variable de entorno `OPENSUBTITLES_API_KEY`.
/// - Sin exposición de claves ni tokens en logs ni en código.
/// - Consulta oficial: GET https://api.opensubtitles.com/api/v1/subtitles
/// - Descarga oficial: POST https://api.opensubtitles.com/api/v1/download
/// - Validación estricta de formato SRT/VTT.
/// - Rechazo de HTML, JSON de error y archivos superiores a 1 MB.
/// - Caché local en memoria.
/// - Manejo controlado de 401 (Unauthorized), 429 (Rate Limit) y Timeout.
class OpenSubtitlesRepository {
  static const String _defaultApiBase = 'https://api.opensubtitles.com/api/v1';
  static const Duration defaultTimeout = Duration(seconds: 5);
  static const int maxFileSizeBytes = 1024 * 1024; // 1 MB límite seguro
  static const String userAgent = 'HourTV v1.0';

  final String? _configuredApiKey;
  final String _apiBase;
  final http.Client? client;

  final Map<String, List<HourTvSubtitleTrack>> _cache = {};
  final Map<String, String> _downloadedContentCache = {};

  OpenSubtitlesRepository({
    String? apiKey,
    String? apiBase,
    this.client,
  })  : _configuredApiKey = apiKey,
        _apiBase = (apiBase != null && apiBase.trim().isNotEmpty)
            ? apiBase.trim()
            : _defaultApiBase;

  /// Resuelve la clave de la API respetando la variable de entorno OPENSUBTITLES_API_KEY.
  /// No expone la clave en ningún log ni archivo.
  String get apiKey {
    final configured = _configuredApiKey;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    const envKey = String.fromEnvironment('OPENSUBTITLES_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey.trim();
    }
    try {
      final plat = Platform.environment['OPENSUBTITLES_API_KEY'];
      if (plat != null && plat.trim().isNotEmpty) {
        return plat.trim();
      }
    } catch (_) {}
    return '';
  }

  bool get isConfigured => apiKey.isNotEmpty;

  /// Limpia la caché en memoria (para pruebas).
  void clearCache() {
    _cache.clear();
    _downloadedContentCache.clear();
  }

  /// Recupera el contenido descargado y validado para un track id si está en caché.
  String? getDownloadedContent(String trackId) => _downloadedContentCache[trackId];

  /// Busca y descarga subtítulos validados desde OpenSubtitles.com.
  Future<List<HourTvSubtitleTrack>> searchSubtitles({
    String? title,
    String? year,
    int? season,
    int? episode,
    String? tmdbId,
    String? imdbId,
    List<String> languages = const ['es', 'en'],
    http.Client? httpClient,
  }) async {
    final key = apiKey;
    if (key.isEmpty) {
      debugPrint('[OPENSUBTITLES] not_configured');
      return const [];
    }

    final effectiveLangs = languages.isEmpty ? const ['es', 'en'] : languages;
    final cacheKey = computeCacheKey(
      tmdbId: tmdbId,
      imdbId: imdbId,
      title: title,
      year: year,
      season: season,
      episode: episode,
      languages: effectiveLangs,
    );

    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      debugPrint('[OPENSUBTITLES] cache_hit count=${cached.length}');
      return cached;
    }

    final queryHash = sha256
        .convert(utf8.encode('${title ?? ""}|${tmdbId ?? ""}|${imdbId ?? ""}'))
        .toString()
        .substring(0, 8);
    debugPrint(
      '[OPENSUBTITLES] search_start query_hash=$queryHash lang=${effectiveLangs.join(",")}',
    );

    final effectiveClient = httpClient ?? client ?? http.Client();
    final closeClient = (httpClient == null && client == null);

    try {
      final queryParams = <String, String>{
        'languages': effectiveLangs.map((l) => l.trim().toLowerCase()).join(','),
      };

      if (tmdbId != null && tmdbId.trim().isNotEmpty) {
        queryParams['tmdb_id'] = tmdbId.trim();
      }

      final sanitizedImdb = sanitizeImdbId(imdbId);
      if (sanitizedImdb != null) {
        queryParams['imdb_id'] = sanitizedImdb;
      }

      if (title != null && title.trim().isNotEmpty) {
        queryParams['query'] = title.trim();
      }

      if (year != null && year.trim().isNotEmpty) {
        queryParams['year'] = year.trim();
      }

      if (season != null && episode != null) {
        queryParams['season_number'] = season.toString();
        queryParams['episode_number'] = episode.toString();
        queryParams['type'] = 'episode';
      } else {
        queryParams['type'] = 'movie';
      }

      final searchUri = Uri.parse('$_apiBase/subtitles').replace(
        queryParameters: queryParams,
      );

      final searchHeaders = <String, String>{
        'Api-Key': key,
        'User-Agent': userAgent,
        'Accept': 'application/json',
      };

      final searchResponse = await effectiveClient
          .get(searchUri, headers: searchHeaders)
          .timeout(defaultTimeout);

      if (searchResponse.statusCode == 401) {
        debugPrint('[OPENSUBTITLES] unauthorized_401');
        return const [];
      } else if (searchResponse.statusCode == 429) {
        debugPrint('[OPENSUBTITLES] rate_limited_429');
        return const [];
      } else if (searchResponse.statusCode != 200) {
        debugPrint('[OPENSUBTITLES] http_error status=${searchResponse.statusCode}');
        return const [];
      }

      final decoded = jsonDecode(searchResponse.body);
      if (decoded is! Map || decoded['data'] is! List) {
        debugPrint('[OPENSUBTITLES] tracks_found count=0');
        _cache[cacheKey] = const [];
        return const [];
      }

      final dataList = decoded['data'] as List;
      final foundTracks = <HourTvSubtitleTrack>[];
      final seenLanguages = <String>{};

      for (final item in dataList) {
        if (item is! Map) continue;
        final attributes = item['attributes'];
        if (attributes is! Map) continue;

        final lang = (attributes['language'] ?? 'es').toString().trim().toLowerCase();
        // Para no agotar innecesariamente la cuota de descargas, limitamos a 1-2 por idioma
        if (seenLanguages.where((l) => l == lang).length >= 2) continue;

        final files = attributes['files'];
        if (files is! List || files.isEmpty) continue;

        final firstFile = files.first;
        if (firstFile is! Map) continue;

        final fileId = firstFile['file_id'];
        if (fileId == null) continue;

        // Descarga oficial: POST /api/v1/download
        final track = await _downloadAndValidateTrack(
          client: effectiveClient,
          apiKey: key,
          fileId: fileId is int ? fileId : int.tryParse(fileId.toString()),
          language: lang,
          season: season,
          episode: episode,
        );

        if (track != null) {
          foundTracks.add(track);
          seenLanguages.add(lang);
        }
      }

      final result = List<HourTvSubtitleTrack>.unmodifiable(foundTracks);
      _cache[cacheKey] = result;
      debugPrint('[OPENSUBTITLES] tracks_found count=${result.length}');
      return result;
    } on TimeoutException {
      debugPrint('[OPENSUBTITLES] timeout');
      return const [];
    } catch (e) {
      debugPrint('[OPENSUBTITLES] error type=${e.runtimeType}');
      return const [];
    } finally {
      if (closeClient) effectiveClient.close();
    }
  }

  /// Descarga el archivo de subtítulos con el endpoint oficial y valida su contenido.
  Future<HourTvSubtitleTrack?> _downloadAndValidateTrack({
    required http.Client client,
    required String apiKey,
    required int? fileId,
    required String language,
    int? season,
    int? episode,
  }) async {
    if (fileId == null) return null;

    debugPrint('[OPENSUBTITLES] download_start file_id=$fileId');

    try {
      final downloadUri = Uri.parse('$_apiBase/download');
      final downloadHeaders = <String, String>{
        'Api-Key': apiKey,
        'User-Agent': userAgent,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final downloadBody = jsonEncode({'file_id': fileId});

      final downloadResponse = await client
          .post(downloadUri, headers: downloadHeaders, body: downloadBody)
          .timeout(defaultTimeout);

      if (downloadResponse.statusCode == 401) {
        debugPrint('[OPENSUBTITLES] unauthorized_401');
        return null;
      } else if (downloadResponse.statusCode == 429) {
        debugPrint('[OPENSUBTITLES] rate_limited_429');
        return null;
      } else if (downloadResponse.statusCode != 200) {
        debugPrint('[OPENSUBTITLES] download_error status=${downloadResponse.statusCode}');
        return null;
      }

      final downloadJson = jsonDecode(downloadResponse.body);
      if (downloadJson is! Map || downloadJson['link'] == null) {
        return null;
      }

      final downloadLink = downloadJson['link'].toString();
      final linkUri = Uri.tryParse(downloadLink);
      if (linkUri == null || (!linkUri.scheme.startsWith('http'))) {
        return null;
      }

      // Descarga del contenido real del archivo
      final fileResponse = await client
          .get(linkUri, headers: {'User-Agent': userAgent})
          .timeout(defaultTimeout);

      if (fileResponse.statusCode != 200) {
        debugPrint('[OPENSUBTITLES] file_fetch_error status=${fileResponse.statusCode}');
        return null;
      }

      // 1. Rechazar archivos mayores de 1 MB
      if (fileResponse.bodyBytes.length > maxFileSizeBytes) {
        debugPrint('[OPENSUBTITLES] rejected_too_large bytes=${fileResponse.bodyBytes.length}');
        return null;
      }

      final body = _decodeBody(fileResponse.bodyBytes);
      final trimmed = body.trimLeft();
      final lower = trimmed.toLowerCase();

      // 2. Rechazar HTML
      if (lower.startsWith('<!doctype html') ||
          lower.startsWith('<html') ||
          lower.startsWith('<body') ||
          lower.contains('<head>') ||
          lower.contains('content="text/html')) {
        debugPrint('[OPENSUBTITLES] rejected_html');
        return null;
      }

      // 3. Rechazar JSON de error
      if (trimmed.startsWith('{') &&
          (lower.contains('"error"') ||
           lower.contains('"message"') ||
           lower.contains('"status"'))) {
        debugPrint('[OPENSUBTITLES] rejected_error_json');
        return null;
      }

      // 4. Validar formato SRT / VTT
      final format = validateSubtitleContent(body);
      if (format == SubtitleFormat.unsupported) {
        debugPrint('[OPENSUBTITLES] invalid_format');
        return null;
      }

      final trackId = 'os-$language-$fileId';
      final label = _buildTrackLabel(
        language: language,
        season: season,
        episode: episode,
      );

      _downloadedContentCache[trackId] = body;

      return HourTvSubtitleTrack(
        id: trackId,
        label: label,
        languageCode: language,
        url: downloadLink,
        format: format,
        provenance: SubtitleProvenance.sidecar,
      );
    } on TimeoutException {
      debugPrint('[OPENSUBTITLES] timeout');
      return null;
    } catch (e) {
      debugPrint('[OPENSUBTITLES] download_exception type=${e.runtimeType}');
      return null;
    }
  }

  /// Valida la sintaxis del archivo y devuelve el formato detectado o [SubtitleFormat.unsupported].
  static SubtitleFormat validateSubtitleContent(String content) {
    final trimmed = content.trimLeft();
    if (trimmed.toUpperCase().startsWith('WEBVTT')) {
      return SubtitleFormat.vtt;
    }
    final timestampRegex = RegExp(
      r'\d{1,2}:\d{2}:\d{2}[,\.]\d{2,3}\s*-->\s*\d{1,2}:\d{2}:\d{2}[,\.]\d{2,3}',
    );
    if (timestampRegex.hasMatch(content)) {
      return SubtitleFormat.srt;
    }
    return SubtitleFormat.unsupported;
  }

  /// Sanitiza el identificador de IMDb extrayendo únicamente los dígitos.
  static String? sanitizeImdbId(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isNotEmpty ? digits : null;
  }

  /// Genera una clave determinista para la caché local.
  static String computeCacheKey({
    String? tmdbId,
    String? imdbId,
    String? title,
    String? year,
    int? season,
    int? episode,
    List<String>? languages,
  }) {
    final langStr = (languages ?? const ['es', 'en'])
        .map((l) => l.trim().toLowerCase())
        .join(',');
    final raw =
        'tmdb:$tmdbId|imdb:${sanitizeImdbId(imdbId)}|title:${title?.toLowerCase().trim()}|year:$year|s:$season|e:$episode|lang:$langStr';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static String _buildTrackLabel({
    required String language,
    int? season,
    int? episode,
  }) {
    final langCode = language.toUpperCase();
    final langName = langCode == 'ES'
        ? 'Español'
        : (langCode == 'EN' ? 'Inglés' : langCode);

    if (season != null && episode != null) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      return 'OpenSubtitles ($langName S${s}E$e)';
    }
    return 'OpenSubtitles ($langName)';
  }

  static String _decodeBody(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }
}
