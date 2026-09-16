import 'dart:collection';
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

    final isRestricted = isKidsProfile || ParentalControlService.isEnabled;

    final seenIds = <String>{};
    if (targetTitleId != null && targetTitleId.isNotEmpty) seenIds.add(targetTitleId);
    if (targetUrl.isNotEmpty) seenIds.add(targetUrl);
    if (targetStableId != null && targetStableId.isNotEmpty) seenIds.add(targetStableId);
    if (targetName.isNotEmpty) seenIds.add(targetName);

    final scoredCandidates = <ScoredRelatedItem>[];

    for (final candidate in candidates) {
      // 1. Excluir target por cualquier identidad
      final candTitleId = candidate.catalogTitleId?.trim().toLowerCase();
      final candUrl = candidate.url.trim().toLowerCase();
      final candStableId = candidate.stableTitleId?.trim().toLowerCase();
      final candName = candidate.displayName.trim().toLowerCase();

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
      final isSameType = (candidate.type == target.type) ||
          (candidate.forcedType?.toLowerCase() == target.forcedType?.toLowerCase());
      if (isSameType) {
        breakdown['media_type'] = 10.0;
        totalScore += 10.0;
      }

      // B. Géneros en común (coeficiente Jaccard normalizado hasta 40.0 pts)
      final candGenres = _extractTokens(candidate.genre);
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
      final candDirector = _extractTokens(candidate.director);
      if (targetDirector.isNotEmpty && candDirector.isNotEmpty) {
        final commonDirectors = targetDirector.intersection(candDirector).length;
        if (commonDirectors > 0) {
          final dirScore = commonDirectors * 20.0;
          breakdown['director'] = dirScore;
          totalScore += dirScore;
        }
      }

      // D. Reparto (Cast) en común (hasta 15.0 pts)
      final candCast = _extractTokens(candidate.cast);
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
        final candCleanPrefix = _extractCleanPrefix(candidate.displayName);
        if (candCleanPrefix.length >= 6 && candCleanPrefix == targetCleanPrefix) {
          breakdown['clean_franchise_prefix'] = 25.0;
          totalScore += 25.0;
        }
      }

      // F. Misma década (hasta 5.0 pts)
      final candYear = int.tryParse(candidate.year?.trim() ?? '');
      if (targetYear != null && candYear != null && targetYear > 1900 && candYear > 1900) {
        final targetDecade = targetYear ~/ 10;
        final candDecade = candYear ~/ 10;
        if (targetDecade == candDecade) {
          breakdown['decade'] = 5.0;
          totalScore += 5.0;
        }
      }

      // G. Puntuación / Rating cercano (hasta 5.0 pts)
      final candRating = double.tryParse(candidate.rating?.trim() ?? '');
      if (targetRating != null && candRating != null) {
        final diff = (targetRating - candRating).abs();
        if (diff <= 1.0) {
          final rScore = (1.0 - diff) * 5.0;
          breakdown['rating_proximity'] = rScore;
          totalScore += rScore;
        }
      }

      // Base mínima de ordenación
      totalScore = double.parse(totalScore.toStringAsFixed(2));

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

      final ratingA = double.tryParse(a.channel.rating ?? '') ?? 0.0;
      final ratingB = double.tryParse(b.channel.rating ?? '') ?? 0.0;
      final cmpRating = ratingB.compareTo(ratingA);
      if (cmpRating != 0) return cmpRating;

      final yearA = int.tryParse(a.channel.year ?? '') ?? 0;
      final yearB = int.tryParse(b.channel.year ?? '') ?? 0;
      final cmpYear = yearB.compareTo(yearA);
      if (cmpYear != 0) return cmpYear;

      return a.channel.displayName.compareTo(b.channel.displayName);
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
  static String _extractCleanPrefix(String title) {
    var clean = title.trim();
    // Remover año entre paréntesis "(1999)"
    clean = clean.replaceAll(RegExp(r'\(\d{4}\)'), '');
    // Remover temporadas "Temporada 1", "Season 2", "T1", "S02"
    clean = clean.replaceAll(RegExp(r'(?:temporada|season|temp\.?|t|s)\s*\d+', caseSensitive: false), '');
    // Cortar en subtítulo principal (":", "-", "—")
    if (clean.contains(':')) {
      clean = clean.split(':').first;
    } else if (clean.contains(' - ')) {
      clean = clean.split(' - ').first;
    }
    // Remover números arábigos o romanos al final (ej. "Matrix 2", "Toy Story II")
    clean = clean.replaceAll(RegExp(r'\b(?:[0-9]+|[ivxcdm]+)\b', caseSensitive: false), '');
    // Normalizar a caracteres alfanuméricos
    clean = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), ' ').trim();
    // Si quedan palabras vacías o palabras comunes como "the", "el", "la", removerlas
    final words = clean.split(' ').where((w) => w.length > 2 && !{'the', 'las', 'los', 'les'}.contains(w)).toList();
    return words.join(' ').trim();
  }

  static Set<String> _extractTokens(String? input) {
    if (input == null || input.trim().isEmpty) return const {};
    return input
        .toLowerCase()
        .split(RegExp(r'[,/|;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length >= 2)
        .toSet();
  }
}
