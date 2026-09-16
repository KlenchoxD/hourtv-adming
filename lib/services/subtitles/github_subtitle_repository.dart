import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage_service.dart';
import 'hourtv_subtitle_track.dart';

/// Proveedor de subtítulos alojados en repositorios GitHub o servidores raw compatibles.
///
/// Diseñado para consultar de forma determinista y segura sin bloquear la inicialización
/// del reproductor, con caché en memoria, rechazo de respuestas HTML/binarias y
/// sanitización de logs.
class GithubSubtitleRepository {
  static const Duration defaultTimeout = Duration(seconds: 5);
  static const int maxFileSizeBytes = 1024 * 1024; // 1 MB límite seguro

  final String? _configuredBaseUrl;
  final String? _configuredToken;
  final bool? _configuredEnabled;
  final http.Client? client;

  final Map<String, List<HourTvSubtitleTrack>> _cache = {};

  GithubSubtitleRepository({
    String? baseUrl,
    String? token,
    bool? enabled,
    this.client,
  })  : _configuredBaseUrl = baseUrl,
        _configuredToken = token,
        _configuredEnabled = enabled;

  bool get isEnabled {
    final configured = _configuredEnabled;
    if (configured != null) return configured;
    final setting = StorageService.getSetting('subtitleRepositoryEnabled');
    if (setting is bool) return setting;
    if (setting is String) return setting.toLowerCase() == 'true';
    return false;
  }

  String? get baseUrl {
    final configured = _configuredBaseUrl;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    final setting = StorageService.getSetting('subtitleRepositoryBaseUrl')
        ?.toString()
        .trim();
    return (setting != null && setting.isNotEmpty) ? setting : null;
  }

  String? get token {
    final configured = _configuredToken;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    final setting = StorageService.getSetting('subtitleRepositoryToken')
        ?.toString()
        .trim();
    return (setting != null && setting.isNotEmpty) ? setting : null;
  }

  /// Limpia la caché en memoria (para pruebas o al cerrar sesión).
  void clearCache() => _cache.clear();

  /// Busca subtítulos para una película o episodio de serie.
  Future<List<HourTvSubtitleTrack>> searchSubtitles({
    required String title,
    String? year,
    int? season,
    int? episode,
    String? language,
    String? imdbId,
    String? tmdbId,
    http.Client? httpClient,
  }) async {
    final effectiveBase = baseUrl;
    if (!isEnabled || effectiveBase == null) {
      debugPrint('[SUBTITLES_GH] disabled_or_not_configured');
      return const [];
    }

    final lang = (language ?? 'es').trim().toLowerCase();
    final cacheKey = _computeCacheKey(
      title: title,
      year: year,
      season: season,
      episode: episode,
      language: lang,
    );

    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      debugPrint('[SUBTITLES_GH] cache_hit count=${cached.length}');
      return cached;
    }

    final titleHash = sha256.convert(utf8.encode(title.toLowerCase())).toString().substring(0, 8);
    debugPrint('[SUBTITLES_GH] query title_hash=$titleHash lang=$lang');

    final effectiveClient = httpClient ?? client ?? http.Client();
    final closeClient = (httpClient == null && client == null);

    try {
      final candidates = _buildCandidateUrls(
        baseUrl: effectiveBase,
        title: title,
        year: year,
        season: season,
        episode: episode,
        language: lang,
        imdbId: imdbId,
        tmdbId: tmdbId,
      );

      final foundTracks = <HourTvSubtitleTrack>[];

      for (final candidateUrl in candidates) {
        final uri = Uri.tryParse(candidateUrl);
        if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) continue;

        try {
          final requestHeaders = <String, String>{
            'User-Agent': 'HourTV-Subtitles/1.0',
            if (token != null && token!.isNotEmpty)
              'Authorization': 'token ${token!}',
          };

          final response = await effectiveClient.get(uri, headers: requestHeaders).timeout(defaultTimeout);

          if (response.statusCode != 200) continue;

          // Validar tamaño máximo
          if (response.bodyBytes.length > maxFileSizeBytes) {
            debugPrint('[SUBTITLES_GH] rejected_too_large bytes=${response.bodyBytes.length}');
            continue;
          }

          final body = _decodeBody(response.bodyBytes);
          final validation = validateSubtitleContent(body);

          if (validation == SubtitleFormat.unsupported) {
            final lower = body.trimLeft().toLowerCase();
            if (lower.startsWith('<!doctype html') || lower.startsWith('<html') || lower.startsWith('<body')) {
              debugPrint('[SUBTITLES_GH] rejected_html');
            }
            continue;
          }

          final label = _buildTrackLabel(language: lang, season: season, episode: episode);
          final trackId = 'gh-${validation.name}-$lang-${uri.path.hashCode.abs()}';

          foundTracks.add(
            HourTvSubtitleTrack(
              id: trackId,
              label: label,
              languageCode: lang,
              url: uri.toString(),
              format: validation,
              provenance: SubtitleProvenance.sidecar,
            ),
          );

          if (foundTracks.isNotEmpty) break;
        } on TimeoutException {
          debugPrint('[SUBTITLES_GH] timeout');
        } catch (e) {
          debugPrint('[SUBTITLES_GH] candidate_error type=${e.runtimeType}');
        }
      }

      final result = List<HourTvSubtitleTrack>.unmodifiable(foundTracks);
      _cache[cacheKey] = result;
      debugPrint('[SUBTITLES_GH] result tracks_found=${result.length}');
      return result;
    } catch (e) {
      debugPrint('[SUBTITLES_GH] error type=${e.runtimeType}');
      return const [];
    } finally {
      if (closeClient) effectiveClient.close();
    }
  }

  /// Valida la sintaxis del archivo y devuelve el formato detectado o [SubtitleFormat.unsupported].
  static SubtitleFormat validateSubtitleContent(String content) {
    final trimmed = content.trimLeft();
    final lower = trimmed.toLowerCase();

    // Rechazar HTML y respuestas erróneas
    if (lower.startsWith('<!doctype html') ||
        lower.startsWith('<html') ||
        lower.startsWith('<body') ||
        lower.startsWith('{"message":') ||
        lower.startsWith('{"error":')) {
      return SubtitleFormat.unsupported;
    }

    if (trimmed.startsWith('WEBVTT')) {
      return SubtitleFormat.vtt;
    }

    // Validación SRT: debe contener al menos un timestamp `-->`
    if (content.contains('-->')) {
      final srtRegex = RegExp(r'\d{2}:\d{2}:\d{2}[,\.]\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}[,\.]\d{3}');
      if (srtRegex.hasMatch(content)) {
        return SubtitleFormat.srt;
      }
    }

    return SubtitleFormat.unsupported;
  }

  static String _decodeBody(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  static String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static List<String> _buildCandidateUrls({
    required String baseUrl,
    required String title,
    String? year,
    int? season,
    int? episode,
    required String language,
    String? imdbId,
    String? tmdbId,
  }) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final slug = _slugify(title);
    final candidates = <String>[];

    final isSeries = (season != null && episode != null);

    if (isSeries) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      candidates.add('$cleanBase/series/$slug/S${s}E$e.$language.srt');
      candidates.add('$cleanBase/series/$slug/S${s}E$e.$language.vtt');
      candidates.add('$cleanBase/series/$slug/S${s}E$e.srt');
      candidates.add('$cleanBase/series/$slug/S${s}E$e.vtt');
      candidates.add('$cleanBase/$slug/S${s}E$e.$language.srt');
    } else {
      final y = (year != null && year.trim().isNotEmpty) ? '_${year.trim()}' : '';
      candidates.add('$cleanBase/movies/$slug$y.$language.srt');
      candidates.add('$cleanBase/movies/$slug$y.$language.vtt');
      candidates.add('$cleanBase/movies/$slug.$language.srt');
      candidates.add('$cleanBase/movies/$slug.$language.vtt');
      candidates.add('$cleanBase/$slug$y.$language.srt');
    }

    return candidates;
  }

  static String _computeCacheKey({
    required String title,
    String? year,
    int? season,
    int? episode,
    required String language,
  }) {
    return '${title.trim().toLowerCase()}|${year ?? ''}|${season ?? ''}|${episode ?? ''}|$language';
  }

  static String _buildTrackLabel({
    required String language,
    int? season,
    int? episode,
  }) {
    final langName = switch (language.toLowerCase()) {
      'es' || 'spa' => 'Español',
      'en' || 'eng' => 'Inglés',
      'pt' || 'por' => 'Portugués',
      'fr' || 'fra' => 'Francés',
      'it' || 'ita' => 'Italiano',
      'de' || 'deu' => 'Alemán',
      _ => language.toUpperCase(),
    };
    return '$langName (GitHub)';
  }
}
