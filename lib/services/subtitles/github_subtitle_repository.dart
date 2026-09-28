import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/channel.dart';
import '../catalog/catalog_repository.dart';
import '../content_store.dart';
import 'hourtv_subtitle_track.dart';

/// Subtítulos en español del repositorio público `hourtv-subtitles`. Una
/// tarea diaria de GitHub los baja de SubDL por TMDB id, así la clave de
/// SubDL nunca viaja dentro de la app:
///
///   movie/<tmdb>.es.srt
///   tv/<id de la serie en el catálogo>/S01E02.es.srt
class GithubSubtitleRepository {
  static const String defaultBaseUrl =
      'https://raw.githubusercontent.com/KlenchoxD/hourtv-subtitles/main';
  static const Duration defaultTimeout = Duration(seconds: 5);
  static const int maxFileSizeBytes = 1024 * 1024; // 1 MB límite seguro

  GithubSubtitleRepository({this.baseUrl = defaultBaseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  final Map<String, List<HourTvSubtitleTrack>> _cache = {};

  /// Limpia la caché en memoria (para pruebas o al cerrar sesión).
  void clearCache() => _cache.clear();

  /// URL del subtítulo de una película ([tmdbId]) o de un episodio
  /// ([seriesId] del catálogo, [season] y [episode]).
  String? urlFor({
    int? tmdbId,
    String? seriesId,
    int? season,
    int? episode,
    String language = 'es',
  }) {
    if (seriesId != null && season != null && episode != null) {
      final s = season.toString().padLeft(2, '0');
      final e = episode.toString().padLeft(2, '0');
      return '$baseUrl/tv/$seriesId/S${s}E$e.$language.srt';
    }
    return tmdbId == null ? null : '$baseUrl/movie/$tmdbId.$language.srt';
  }

  /// Clave del repositorio de subtítulos: el TMDB id que trae el catálogo
  /// JSON (episodios: el de la serie + "…:temporada:episodio" del tvgId) o,
  /// si no, la ficha del catálogo local.
  static Future<({int? tmdbId, String? seriesId, int? season, int? episode})?>
  keyFor(Channel channel) async {
    // "Continuar viendo" guardado antes de existir tmdbId: se toma del mismo
    // título en el catálogo cargado.
    final tvgId = channel.tvgId;
    final tmdb =
        channel.tmdbId ??
        (tvgId == null
            ? null
            : [
                ...ContentStore.instance.all,
                for (final s in ContentStore.instance.series) ...?s.episodes,
              ].where((c) => c.tvgId == tvgId).firstOrNull?.tmdbId);
    if (tmdb != null) {
      if (channel.type != MediaType.series) {
        return (tmdbId: tmdb, seriesId: null, season: null, episode: null);
      }
      final parts = (channel.tvgId ?? '').split(':');
      final season = parts.length >= 3
          ? int.tryParse(parts[parts.length - 2])
          : null;
      final episode = parts.length >= 3 ? int.tryParse(parts.last) : null;
      if (season != null && episode != null) {
        return (
          tmdbId: null,
          seriesId: '$tmdb',
          season: season,
          episode: episode,
        );
      }
    }
    final catalogId = channel.stableTitleId;
    if (catalogId == null || !CatalogRepository.hasInstance) return null;
    return CatalogRepository.instance.dao.subtitleKeyFor(catalogId);
  }

  /// Pista en español de [channel] (película o episodio).
  Future<List<HourTvSubtitleTrack>> findFor(Channel channel) async {
    final key = await keyFor(channel);
    if (key == null) {
      debugPrint(
        '[SUBTITLES_GH] sin clave: tvg=${channel.tvgId} '
        'catalog=${channel.catalogTitleId} tmdb=${channel.tmdbId}',
      );
      return const [];
    }
    return find(
      tmdbId: key.tmdbId,
      seriesId: key.seriesId,
      season: key.season,
      episode: key.episode,
    );
  }

  /// Pista en español del título, o vacío si el repositorio aún no la tiene.
  Future<List<HourTvSubtitleTrack>> find({
    int? tmdbId,
    String? seriesId,
    int? season,
    int? episode,
    String language = 'es',
  }) async {
    final url = urlFor(
      tmdbId: tmdbId,
      seriesId: seriesId,
      season: season,
      episode: episode,
      language: language,
    );
    if (url == null) return const [];
    final cached = _cache[url];
    if (cached != null) return cached;

    final effectiveClient = client ?? http.Client();
    try {
      final response = await effectiveClient
          .get(Uri.parse(url), headers: {'User-Agent': 'HourTV-Subtitles/1.0'})
          .timeout(defaultTimeout);
      var result = const <HourTvSubtitleTrack>[];
      if (response.statusCode == 200 &&
          response.bodyBytes.length <= maxFileSizeBytes) {
        final format = validateSubtitleContent(_decodeBody(response.bodyBytes));
        if (format != SubtitleFormat.unsupported) {
          result = [
            HourTvSubtitleTrack(
              id: 'gh-${format.name}-$language-${url.hashCode.abs()}',
              label: _label(language),
              languageCode: language,
              url: url,
              format: format,
              provenance: SubtitleProvenance.sidecar,
            ),
          ];
        }
      }
      // 404 también se recuerda: no se vuelve a pedir en esta sesión.
      _cache[url] = result;
      debugPrint('[SUBTITLES_GH] tracks_found=${result.length}');
      return result;
    } on TimeoutException {
      debugPrint('[SUBTITLES_GH] timeout');
      return const [];
    } catch (e) {
      debugPrint('[SUBTITLES_GH] error type=${e.runtimeType}');
      return const [];
    } finally {
      if (client == null) effectiveClient.close();
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

  static String _label(String language) => switch (language) {
    'es' => 'Español',
    'en' => 'Inglés',
    'pt' => 'Portugués',
    _ => language.toUpperCase(),
  };
}
