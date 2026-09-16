import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'hourtv_srt_caption_file.dart';
import 'hourtv_subtitle_track.dart';

/// Controlador central de subtítulos de HourTV.
///
/// Responsabilidades:
/// - Selección automática por jerarquía (Forced > Perfil > Default > Off).
/// - Caché LRU de [maxCacheEntries] entradas con clave SHA-256 sanitizada.
/// - Límites durante streaming: no descarga más de [maxFileSizeBytes].
/// - Máximo 3 redirecciones, validadas en tipo, MIME y estructura.
/// - UTF-8 estricto con fallback Latin-1 real.
/// - Epoch / token de cancelación: descarga anterior no aplica al vídeo actual.
/// - Sanitización de errores: no expone URIs, tokens ni query strings en logs.
/// - HLS segmentado no compatible → mensaje explícito, sin afirmar soporte.
class SubtitleController {
  static const int maxCacheEntries = 10;
  static const int maxFileSizeBytes = 1024 * 1024; // 1 MB
  static const Duration requestTimeout = Duration(seconds: 5);
  static const int maxRedirects = 3;

  final LinkedHashMap<String, ClosedCaptionFile> _captionCache =
      LinkedHashMap<String, ClosedCaptionFile>();

  /// Epoch que identifica el vídeo actual. Se incrementa en cada cambio de fuente.
  /// Las descargas iniciadas con un epoch anterior son canceladas silenciosamente.
  int _currentEpoch = 0;

  /// Incrementa el epoch: las descargas en vuelo para el vídeo anterior no
  /// podrán aplicar sus resultados al vídeo nuevo.
  void advanceEpoch() {
    _currentEpoch++;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Selección automática
  // ─────────────────────────────────────────────────────────────────────────

  /// Resuelve la pista automática según jerarquía de negocio:
  /// 1. Pista forzada (forced) en el idioma preferido.
  /// 2. Pista en el idioma preferido del perfil.
  /// 3. Pista marcada como default.
  /// 4. Si ninguna coincide o la lista está vacía → off.
  static HourTvSubtitleTrack resolveAutomaticTrack({
    required List<HourTvSubtitleTrack> tracks,
    required String profileLanguage,
  }) {
    if (tracks.isEmpty) return HourTvSubtitleTrack.off;

    final normProfile = profileLanguage.trim().toLowerCase();

    // 1. Forced coincidente con idioma de perfil
    final forcedMatch = tracks.firstWhere(
      (t) =>
          t.isForced &&
          (normProfile.isEmpty || t.languageCode.toLowerCase() == normProfile),
      orElse: () => tracks.firstWhere(
        (t) => t.isForced,
        orElse: () => HourTvSubtitleTrack.off,
      ),
    );
    if (forcedMatch.id != 'off') return forcedMatch;

    // 2. Coincidencia por idioma del perfil
    if (normProfile.isNotEmpty &&
        normProfile != 'auto' &&
        normProfile != 'off') {
      final langMatch = tracks.firstWhere(
        (t) => t.languageCode.toLowerCase() == normProfile,
        orElse: () => HourTvSubtitleTrack.off,
      );
      if (langMatch.id != 'off') return langMatch;
    }

    // 3. Pista por defecto
    final defaultMatch = tracks.firstWhere(
      (t) => t.isDefault,
      orElse: () => HourTvSubtitleTrack.off,
    );
    if (defaultMatch.id != 'off') return defaultMatch;

    return HourTvSubtitleTrack.off;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filtrado de cabeceras
  // ─────────────────────────────────────────────────────────────────────────

  /// Filtra cabeceras seguras para peticiones de subtítulos sidecar.
  /// No transfiere cabeceras de autorización o cookies a hosts externos.
  static Map<String, String> filterSafeHeaders({
    required String sourceHost,
    required Uri targetUri,
    required Map<String, String> sourceHeaders,
  }) {
    final safe = <String, String>{};
    final isSameHost =
        sourceHost.isNotEmpty &&
        targetUri.host.toLowerCase() == sourceHost.toLowerCase();

    for (final entry in sourceHeaders.entries) {
      final keyLower = entry.key.toLowerCase();
      if (keyLower == 'user-agent') {
        safe[entry.key] = entry.value;
      } else if (keyLower == 'referer' && isSameHost) {
        safe[entry.key] = entry.value;
      } else if ((keyLower == 'authorization' || keyLower == 'cookie') &&
          isSameHost) {
        safe[entry.key] = entry.value;
      }
    }
    return safe;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Clave de caché (SHA-256 sanitizado, sin secreto HMAC hardcodeado)
  // ─────────────────────────────────────────────────────────────────────────

  /// Genera un digest SHA-256 de una representación sanitizada de la URL y
  /// el trackId para usarlo como clave de caché.
  ///
  /// No usa HMAC con clave constante hardcodeada: SHA-256 es suficiente para
  /// identidad de caché. Se usa la URI completa para que dos URLs firmadas con
  /// tokens distintos no compartan una entrada obsoleta. La URI nunca se
  /// registra: solo se conserva el digest irreversible en memoria.
  static String computeCacheKey(Uri uri, String trackId) {
    final bytes = utf8.encode('${uri.toString()}|$trackId');
    return sha256.convert(bytes).toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validación de MIME y estructura
  // ─────────────────────────────────────────────────────────────────────────

  /// Valida que el cuerpo no sea una página de bloqueo o error HTML/JSON.
  static bool _isAcceptableBody(String body) {
    final trimmed = body.trimLeft();
    final lower = trimmed.toLowerCase();
    // Rechazar HTML
    if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
      return false;
    }
    // Rechazar JSON
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Decodificación UTF-8 con fallback Latin-1
  // ─────────────────────────────────────────────────────────────────────────

  /// Intenta UTF-8 estricto. Si falla, usa Latin-1 (ISO-8859-1) real como fallback.
  /// No usa allowMalformed: true como única estrategia.
  static String _decodeBody(List<int> bytes, String? charsetHint) {
    final hint = (charsetHint ?? '').toLowerCase();
    // Si el servidor declara explícitamente latin-1, ir directo
    if (hint.contains('latin') || hint.contains('iso-8859-1')) {
      return latin1.decode(bytes);
    }
    // Primero UTF-8 estricto
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // Fallback a Latin-1 (conserva todos los bytes 0x80-0xFF sin reemplazos)
      return latin1.decode(bytes);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sanitización de errores
  // ─────────────────────────────────────────────────────────────────────────

  /// Extrae un descriptor de error seguro que no expone URIs, tokens ni
  /// query strings. Solo registra el tipo de excepción y código HTTP si aplica.
  static String _sanitizeError(Object e) {
    final type = e.runtimeType.toString();
    // TimeoutException, SocketException, etc. → solo tipo
    if (e is http.ClientException) {
      return '[$type] network error';
    }
    final str = e.toString();
    // Si el mensaje contiene "://" (URL) lo reemplazamos
    if (str.contains('://') || str.contains('token') || str.contains('key')) {
      return '[$type] (details redacted)';
    }
    return '[$type] ${str.length > 120 ? str.substring(0, 120) : str}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Descarga principal con redirecciones manuales y límite de tamaño en streaming
  // ─────────────────────────────────────────────────────────────────────────

  /// Descarga y parsea el archivo de subtítulos según su formato (VTT o SRT).
  ///
  /// Parámetros:
  /// - [track]: pista a descargar.
  /// - [httpClient]: cliente HTTP inyectable (tests).
  ///
  /// Retorna null si la pista es de tipo HLS segmentado (no compatible),
  /// si el tamaño supera el límite, si el MIME/cuerpo es inválido,
  /// o si el epoch del contexto ha cambiado (cambio de vídeo).
  Future<ClosedCaptionFile?> loadCaptionFile(
    HourTvSubtitleTrack track, {
    http.Client? httpClient,
  }) async {
    if (track.url == null || track.url!.isEmpty) return null;

    // HLS segmentado: no compatible con VideoPlayerController.setClosedCaptionFile
    if (track.isHlsMediaPlaylist) {
      debugPrint(
        '[SUBTITLES] Subtítulo HLS no compatible con el reproductor actual',
      );
      return null;
    }

    final uri = Uri.tryParse(track.url!);
    if (uri == null) return null;

    final cacheKey = computeCacheKey(uri, track.id);
    if (_captionCache.containsKey(cacheKey)) {
      final cached = _captionCache.remove(cacheKey)!;
      _captionCache[cacheKey] = cached; // touch LRU
      return cached;
    }

    final epochAtStart = _currentEpoch;
    final client = httpClient ?? http.Client();
    try {
      // Descarga con redirecciones manuales (máximo [maxRedirects])
      final bodyBytes = await _fetchWithRedirects(
        client,
        uri,
        track.requiredHeaders,
        uri.host,
        epochAtStart,
      );
      if (bodyBytes == null) return null;

      // Verificar que el epoch sigue siendo el mismo
      if (_currentEpoch != epochAtStart) return null;

      // A. Límite de tamaño durante streaming (ya validado en _fetchWithRedirects)
      // El método ya devuelve null si se supera 1 MB.

      // Decodificar con UTF-8 estricto / Latin-1 fallback
      final charsetHint = track.charset;
      final body = _decodeBody(bodyBytes, charsetHint).trim();

      // B. Validar MIME/cuerpo: rechazar HTML, JSON, páginas de bloqueo
      if (!_isAcceptableBody(body)) {
        return null;
      }

      ClosedCaptionFile? captionFile;
      if (track.format == SubtitleFormat.srt || body.contains('-->')) {
        try {
          captionFile = HourTvSrtCaptionFile(body);
        } catch (_) {
          try {
            captionFile = WebVTTCaptionFile(body);
          } catch (_) {}
        }
      } else {
        try {
          captionFile = WebVTTCaptionFile(body);
        } catch (_) {
          try {
            captionFile = HourTvSrtCaptionFile(body);
          } catch (_) {}
        }
      }

      if (captionFile != null) {
        // LRU eviction
        if (_captionCache.length >= maxCacheEntries) {
          _captionCache.remove(_captionCache.keys.first);
        }
        _captionCache[cacheKey] = captionFile;
      }

      return captionFile;
    } catch (e) {
      // Error sanitizado: no expone URI, tokens ni query strings
      debugPrint('[SUBTITLES] ${_sanitizeError(e)}');
      return null;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  /// Descarga el cuerpo de [uri] siguiendo redirecciones manualmente.
  ///
  /// - Máximo [maxRedirects] saltos.
  /// - Valida MIME de cada respuesta.
  /// - Aplica límite de tamaño durante la lectura (sin bajar todo el cuerpo antes).
  /// - Devuelve null si el epoch cambió entre peticiones.
  Future<List<int>?> _fetchWithRedirects(
    http.Client client,
    Uri uri,
    Map<String, String> sourceHeaders,
    String sourceHost,
    int epochAtStart,
  ) async {
    var current = uri;
    for (var hop = 0; hop <= maxRedirects; hop++) {
      if (_currentEpoch != epochAtStart) return null;

      final http.StreamedResponse streamed;
      try {
        // Volver a filtrar en cada salto. Así Authorization, Cookie y Referer
        // jamás cruzan al host de una redirección externa.
        final headers = filterSafeHeaders(
          sourceHost: sourceHost,
          targetUri: current,
          sourceHeaders: sourceHeaders,
        );
        final request = http.Request('GET', current)..headers.addAll(headers);
        streamed = await client.send(request).timeout(requestTimeout);
      } on TimeoutException {
        return null;
      } catch (e) {
        debugPrint('[SUBTITLES] ${_sanitizeError(e)}');
        return null;
      }

      // Redireccionamiento (301/302/303/307/308)
      if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
        final location = streamed.headers['location'];
        if (location == null || location.isEmpty || hop == maxRedirects) {
          return null;
        }
        // Validar destino: debe ser http/https
        final next = Uri.tryParse(location);
        if (next == null || (next.scheme != 'http' && next.scheme != 'https')) {
          return null;
        }
        current = current.resolveUri(next);
        await streamed.stream.drain<void>(); // consumir para liberar conexión
        continue;
      }

      if (streamed.statusCode != 200) return null;

      // Validar MIME antes de bajar el cuerpo
      final contentType = (streamed.headers['content-type'] ?? '')
          .toLowerCase();
      if (contentType.contains('text/html') ||
          contentType.contains('application/json') ||
          contentType.contains('application/javascript')) {
        await streamed.stream.drain<void>();
        return null;
      }

      // A. Límite de tamaño durante streaming, sin descargar todo primero
      final buffer = <int>[];
      try {
        await for (final chunk in streamed.stream.timeout(requestTimeout)) {
          if (_currentEpoch != epochAtStart) return null;
          buffer.addAll(chunk);
          if (buffer.length > maxFileSizeBytes) {
            return null; // supera límite: rechazar sin descargar el resto
          }
        }
      } on TimeoutException {
        return null;
      }

      return buffer;
    }
    return null; // se agotaron los saltos permitidos
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tamaño del caché LRU (expuesto para tests)
  // ─────────────────────────────────────────────────────────────────────────

  /// Número de entradas actuales en el caché LRU.
  int get cacheSize => _captionCache.length;

  /// Vacía el caché (útil al cambiar de perfil o al limpiar sesión).
  void clearCache() => _captionCache.clear();
}
