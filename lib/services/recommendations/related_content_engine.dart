import 'dart:collection';
import 'package:flutter/scheduler.dart';
import '../../models/channel.dart';
import '../parental_control_service.dart';

/// Resultado de puntuación de un elemento relacionado con desglose explicable.
class ScoredRelatedItem {
  final Channel channel;
  final double score;
  final Map<String, double> breakdown;

  const ScoredRelatedItem({
    required this.channel,
    required this.score,
    required this.breakdown,
  });

  @override
  String toString() =>
      'ScoredRelatedItem(title: ${channel.displayName}, score: $score, breakdown: $breakdown)';
}

/// Motor de contenido relacionado multidimensional compartido para películas y series.
///
/// Reglas de negocio:
/// 1. Exclusión total del título actual por identidad (catalogTitleId, url, stableTitleId, name).
/// 2. Deduplicación estricta por `tmdbId` e identidad (no se usa `tmdbId` para puntuar franquicia).
/// 3. Franquicia: Sin `collectionId`, solo detección conservadora de prefijo limpio >= 6 caracteres alfanuméricos.
/// 4. Multidimensional: género (Jaccard), tipo de medio, director, cast, década, rating.
/// 5. Caché LRU de 50 entradas con clave de invalidación compuesta (targetId, isKids, candidatosRevision).
/// 6. Perfil infantil: respeta `isKidsSafe` y excluye contenido adulto.
class RelatedContentEngine {
  static final RelatedContentEngine instance = RelatedContentEngine();

  final int maxCacheEntries;
  final LinkedHashMap<String, List<ScoredRelatedItem>> _lruCache;

  RelatedContentEngine({this.maxCacheEntries = 50})
      : _lruCache = LinkedHashMap<String, List<ScoredRelatedItem>>();

  /// Limpia la caché LRU (ej. al cambiar perfil o recargar catálogo)
  void clearCache() {
    _lruCache.clear();
  }

  /// Precalcula los datos por candidato en tandas, cediendo el hilo entre
  /// tandas para que la UI siga dibujando. Después, getRelated es barato.
  Future<void> warmUp(List<Channel> candidates) async {
    final budget = Stopwatch()..start();
    for (var i = 0; i < candidates.length; i++) {
      _featuresOf(candidates[i]);
      if (budget.elapsedMilliseconds >= 6) {
        await SchedulerBinding.instance.endOfFrame;
        budget.reset();
      }
    }
  }

  /// Retorna los elementos relacionados como lista de Channels.
  List<Channel> getRelated({
    required Channel target,
    required List<Channel> candidates,
    bool isKidsProfile = false,
    int limit = 6,
  }) {
    final scored = getRelatedWithScore(
      target: target,
      candidates: candidates,
      isKidsProfile: isKidsProfile,
      limit: limit,
    );
    return scored.map((item) => item.channel).toList();
  }

  /// Retorna los elementos relacionados con su puntuación y desglose de score.
  List<ScoredRelatedItem> getRelatedWithScore({
    required Channel target,
    required List<Channel> candidates,
    bool isKidsProfile = false,
    int limit = 6,
  }) {
    if (candidates.isEmpty) return const [];

    final cacheKey = '${target.catalogTitleId ?? target.url}_${isKidsProfile}_${candidates.length}_$limit';
    if (_lruCache.containsKey(cacheKey)) {
      final cached = _lruCache.remove(cacheKey)!;
      _lruCache[cacheKey] = cached;
      return cached;
    }

    final targetTitleId = target.catalogTitleId?.trim().toLowerCase();
    final targetUrl = target.url.trim().toLowerCase();
    final targetStableId = target.stableTitleId?.trim().toLowerCase();
    final targetName = target.displayName.trim().toLowerCase();
    final targetCleanPrefix = _extractCleanPrefix(target.displayName);

    final targetGenres = _extractTokens(target.genre);
    final targetCast = _extractTokens(target.cast);
    final targetDirector = _extractTokens(target.director);
    final targetYear = int.tryParse(target.year?.trim() ?? '');
    final targetRating = double.tryParse(target.rating?.trim() ?? '');
    final targetType = target.type;
    final targetForcedType = target.forcedType?.toLowerCase();

    final isRestricted = isKidsProfile || ParentalControlService.isEnabled;

    final seenIds = <String>{};
    if (targetTitleId != null && targetTitleId.isNotEmpty) seenIds.add(targetTitleId);
    if (targetUrl.isNotEmpty) seenIds.add(targetUrl);
    if (targetStableId != null && targetStableId.isNotEmpty) seenIds.add(targetStableId);
    if (targetName.isNotEmpty) seenIds.add(targetName);

    final scoredCandidates = <ScoredRelatedItem>[];

    for (final candidate in candidates) {
      // 1. Excluir target por cualquier identidad
      final feat = _featuresOf(candidate);
      final candTitleId = feat.titleId;
      final candUrl = feat.url;
      final candStableId = feat.stableId;
      final candName = feat.name;

      if ((candTitleId != null && seenIds.contains(candTitleId)) ||
          (candUrl.isNotEmpty && seenIds.contains(candUrl)) ||
          (candStableId != null && seenIds.contains(candStableId)) ||
          (candName.isNotEmpty && candName == targetName)) {
        continue;
      }

      // 3. Filtro infantil
      if (isRestricted) {
        if (!candidate.isKidsSafe || ParentalControlService.isAdultChannel(candidate)) {
          continue;
        }
      }

      // 4. Cálculo multidimensional de puntuación
      final breakdown = <String, double>{};
      double totalScore = 0.0;

      // A. Mismo tipo de medio (película vs serie) - Base 10.0
      final isSameType = (feat.type == targetType) ||
          (feat.forcedType == targetForcedType);
      if (isSameType) {
        breakdown['media_type'] = 10.0;
        totalScore += 10.0;
      }

      // B. Géneros en común (coeficiente Jaccard normalizado hasta 40.0 pts)
      final candGenres = feat.genres;
      if (targetGenres.isNotEmpty && candGenres.isNotEmpty) {
        final intersection = targetGenres.intersection(candGenres).length;
        final union = targetGenres.union(candGenres).length;
        if (union > 0) {
          final jaccard = (intersection / union) * 40.0;
          breakdown['genre_jaccard'] = jaccard;
          totalScore += jaccard;
        }
      }

      // C. Director en común (hasta 20.0 pts)
      final candDirector = feat.director;
      if (targetDirector.isNotEmpty && candDirector.isNotEmpty) {
        final commonDirectors = targetDirector.intersection(candDirector).length;
        if (commonDirectors > 0) {
          final dirScore = commonDirectors * 20.0;
          breakdown['director'] = dirScore;
          totalScore += dirScore;
        }
      }

      // D. Reparto (Cast) en común (hasta 15.0 pts)
      final candCast = feat.cast;
      if (targetCast.isNotEmpty && candCast.isNotEmpty) {
        final commonCast = targetCast.intersection(candCast).length;
        if (commonCast > 0) {
          final castScore = (commonCast * 5.0).clamp(0.0, 15.0);
          breakdown['cast'] = castScore;
          totalScore += castScore;
        }
      }

      // E. Franquicia / Secuela conservadora por prefijo limpio (hasta 25.0 pts)
      if (targetCleanPrefix.length >= 6) {
        final candCleanPrefix = feat.cleanPrefix;
        if (candCleanPrefix.length >= 6 && candCleanPrefix == targetCleanPrefix) {
          breakdown['clean_franchise_prefix'] = 25.0;
          totalScore += 25.0;
        }
      }

      // F. Misma década (hasta 5.0 pts)
      final candYear = feat.year;
      if (targetYear != null && candYear != null && targetYear > 1900 && candYear > 1900) {
        final targetDecade = targetYear ~/ 10;
        final candDecade = candYear ~/ 10;
        if (targetDecade == candDecade) {
          breakdown['decade'] = 5.0;
          totalScore += 5.0;
        }
      }

      // G. Puntuación / Rating cercano (hasta 5.0 pts)
      final candRating = feat.rating;
      if (targetRating != null && candRating != null) {
        final diff = (targetRating - candRating).abs();
        if (diff <= 1.0) {
          final rScore = (1.0 - diff) * 5.0;
          breakdown['rating_proximity'] = rScore;
          totalScore += rScore;
        }
      }

      // Base mínima de ordenación
      // Redondeo numérico: toStringAsFixed+parse por cada candidato era el
      // mayor costo de abrir una ficha (formateo de texto en C).
      totalScore = (totalScore * 100).roundToDouble() / 100;

      scoredCandidates.add(
        ScoredRelatedItem(
          channel: candidate,
          score: totalScore,
          breakdown: breakdown,
        ),
      );

      // Registrar IDs vistos para deduplicar próximos candidatos
      if (candTitleId != null && candTitleId.isNotEmpty) seenIds.add(candTitleId);
      if (candUrl.isNotEmpty) seenIds.add(candUrl);
      if (candStableId != null && candStableId.isNotEmpty) seenIds.add(candStableId);
      if (candName.isNotEmpty) seenIds.add(candName);
    }

    // Ordenar de forma determinista por score DESC, rating DESC, year DESC, displayName ASC
    scoredCandidates.sort((a, b) {
      final cmpScore = b.score.compareTo(a.score);
      if (cmpScore != 0) return cmpScore;

      final fa = _featuresOf(a.channel);
      final fb = _featuresOf(b.channel);
      final cmpRating = (fb.rating ?? 0.0).compareTo(fa.rating ?? 0.0);
      if (cmpRating != 0) return cmpRating;

      final cmpYear = (fb.year ?? 0).compareTo(fa.year ?? 0);
      if (cmpYear != 0) return cmpYear;

      return fa.displayName.compareTo(fb.displayName);
    });

    final result = scoredCandidates.take(limit).toList();

    // Guardar en LRU cache
    if (_lruCache.length >= maxCacheEntries) {
      _lruCache.remove(_lruCache.keys.first);
    }
    _lruCache[cacheKey] = result;

    return result;
  }

  /// Extrae un prefijo de franquicia conservador:
  /// Elimina temporadas, números arábigos/romanos, subtítulos tras dos puntos o guión,
  /// y normaliza a minúsculas alfanuméricas.
  static final _yearRe = RegExp(r'\(\d{4}\)');
  static final _seasonRe = RegExp(
    r'(?:temporada|season|temp\.?|t|s)\s*\d+',
    caseSensitive: false,
  );
  static final _numeralRe = RegExp(
    r'\b(?:[0-9]+|[ivxcdm]+)\b',
    caseSensitive: false,
  );
  static final _nonAlnumRe = RegExp(r'[^a-z0-9áéíóúüñ]+');
  static final _tokenSepRe = RegExp(r'[,/|;]+');

  // Cada ficha puntúa todo el catálogo: tokens y prefijo de cada candidato
  // se calculan una vez por Channel (Expando = sin fugas de memoria).
  // ponytail: si _enrichMovies completa año/rating de un Channel ya visto, su
  // puntaje usa el valor viejo hasta reiniciar; invalidar aquí si importa.
  static final _features = Expando<_CandidateFeatures>();

  static _CandidateFeatures _featuresOf(Channel c) {
    final cached = _features[c];
    if (cached != null) return cached;
    final displayName = c.displayName;
    return _features[c] = _CandidateFeatures(
      titleId: c.catalogTitleId?.trim().toLowerCase(),
      url: c.url.trim().toLowerCase(),
      stableId: c.stableTitleId?.trim().toLowerCase(),
      displayName: displayName,
      name: displayName.trim().toLowerCase(),
      type: c.type,
      forcedType: c.forcedType?.toLowerCase(),
      year: int.tryParse(c.year?.trim() ?? ''),
      rating: double.tryParse(c.rating?.trim() ?? ''),
      genres: _extractTokens(c.genre),
      director: _extractTokens(c.director),
      cast: _extractTokens(c.cast),
      cleanPrefix: _extractCleanPrefix(displayName),
    );
  }

  static String _extractCleanPrefix(String title) {
    var clean = title.trim();
    // Remover año entre paréntesis "(1999)"
    clean = clean.replaceAll(_yearRe, '');
    // Remover temporadas "Temporada 1", "Season 2", "T1", "S02"
    clean = clean.replaceAll(_seasonRe, '');
    // Cortar en subtítulo principal (":", "-", "—")
    if (clean.contains(':')) {
      clean = clean.split(':').first;
    } else if (clean.contains(' - ')) {
      clean = clean.split(' - ').first;
    }
    // Remover números arábigos o romanos al final (ej. "Matrix 2", "Toy Story II")
    clean = clean.replaceAll(_numeralRe, '');
    // Normalizar a caracteres alfanuméricos
    clean = clean.toLowerCase().replaceAll(_nonAlnumRe, ' ').trim();
    // Si quedan palabras vacías o palabras comunes como "the", "el", "la", removerlas
    final words = clean.split(' ').where((w) => w.length > 2 && !{'the', 'las', 'los', 'les'}.contains(w)).toList();
    return words.join(' ').trim();
  }

  static Set<String> _extractTokens(String? input) {
    if (input == null || input.trim().isEmpty) return const {};
    return input
        .toLowerCase()
        .split(_tokenSepRe)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length >= 2)
        .toSet();
  }
}

// Datos derivados de un Channel que no cambian entre fichas.
class _CandidateFeatures {
  _CandidateFeatures({
    required this.titleId,
    required this.url,
    required this.stableId,
    required this.displayName,
    required this.name,
    required this.type,
    required this.forcedType,
    required this.year,
    required this.rating,
    required this.genres,
    required this.director,
    required this.cast,
    required this.cleanPrefix,
  });
  final String? titleId;
  final String url;
  final String? stableId;
  final String displayName;
  final String name;
  final MediaType type;
  final String? forcedType;
  final int? year;
  final double? rating;
  final Set<String> genres;
  final Set<String> director;
  final Set<String> cast;
  final String cleanPrefix;
}
