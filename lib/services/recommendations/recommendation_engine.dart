import '../../database/daos/user_data_dao.dart';
import '../../models/channel.dart';
import '../parental_control_service.dart';

/// Elemento de recomendación con explicación legible y trazable.
class RecommendationItem {
  final Channel channel;
  final String reason;
  final String category;
  final double score;

  const RecommendationItem({
    required this.channel,
    required this.reason,
    required this.category,
    this.score = 1.0,
  });

  @override
  String toString() => 'RecommendationItem(title: ${channel.name}, reason: $reason, score: $score)';
}

/// Motor local de recomendaciones explicables y seguras.
///
/// Implementa un filtro de seguridad dual estricto para perfiles infantiles:
/// 1. Atributo estructurado del catálogo: `isKidsSafe == true`.
/// 2. Filtro heurístico negativo: `!ParentalControlService.isAdultChannel(item)`.
/// Ante cualquier duda o ausencia de contenido verificado, recurre a un fallback vacío.
class RecommendationEngine {
  final UserDataDao userDataDao;

  RecommendationEngine({required this.userDataDao});

  /// Genera recomendaciones personalizadas para el perfil indicado.
  Future<List<RecommendationItem>> getRecommendations({
    required String profileId,
    required bool isKids,
    required List<Channel> catalog,
    int limit = 20,
  }) async {
    if (catalog.isEmpty) return const [];

    // 1. Aplicar filtro dual de seguridad si es perfil infantil o control parental activo
    final isRestricted = isKids || ParentalControlService.isEnabled;
    final safeCandidates = isRestricted
        ? catalog.where((c) => c.isKidsSafe && !ParentalControlService.isAdultChannel(c)).toList()
        : catalog;

    // Fallback seguro ante dudas o ausencia de catálogo infantil
    if (safeCandidates.isEmpty) {
      return const [];
    }

    // Indexar candidatos seguros por id
    final catalogById = <String, Channel>{};
    for (final item in safeCandidates) {
      final key = item.stableTitleId ?? item.name;
      catalogById[key] = item;
    }

    // 2. Obtener datos de usuario (historial, progreso y favoritos)
    final history = await userDataDao.getHistory(profileId, limit: 20);
    final continueWatching = await userDataDao.getContinueWatching(profileId, limit: 20);
    final favorites = await userDataDao.getFavorites(profileId);

    final watchedIds = <String>{};
    final watchedGenres = <String, int>{}; // género -> conteo
    final lastWatchedTitleNames = <String, String>{}; // género -> nombre de título reciente

    for (final h in history) {
      if (h.titleId != null) watchedIds.add(h.titleId!);
      // Buscar género si está en catálogo
      final matched = catalogById[h.titleId];
      if (matched != null && matched.genre != null && matched.genre!.trim().isNotEmpty) {
        final g = matched.genre!.trim();
        watchedGenres[g] = (watchedGenres[g] ?? 0) + 1;
        lastWatchedTitleNames.putIfAbsent(g, () => matched.name);
      }
    }

    for (final cw in continueWatching) {
      if (cw.titleId != null) watchedIds.add(cw.titleId!);
      final matched = catalogById[cw.titleId];
      if (matched != null && matched.genre != null && matched.genre!.trim().isNotEmpty) {
        final g = matched.genre!.trim();
        watchedGenres[g] = (watchedGenres[g] ?? 0) + 1;
        lastWatchedTitleNames.putIfAbsent(g, () => matched.name);
      }
    }

    final favoriteIds = <String>{};
    final favoriteGenres = <String, int>{}; // género -> conteo

    for (final f in favorites) {
      if (f.titleId != null) favoriteIds.add(f.titleId!);
      final matched = catalogById[f.titleId];
      if (matched != null && matched.genre != null && matched.genre!.trim().isNotEmpty) {
        final g = matched.genre!.trim();
        favoriteGenres[g] = (favoriteGenres[g] ?? 0) + 1;
      }
    }

    final results = <String, RecommendationItem>{};

    // Pista 1: Basado en historial / recientemente visto
    for (final candidate in safeCandidates) {
      final id = candidate.stableTitleId ?? candidate.name;
      if (watchedIds.contains(id)) continue; // No recomendar lo ya visto en esta pista

      final g = candidate.genre?.trim();
      if (g != null && watchedGenres.containsKey(g)) {
        final count = watchedGenres[g]!;
        final sourceTitle = lastWatchedTitleNames[g];
        final reason = sourceTitle != null
            ? 'Porque viste $sourceTitle (en $g)'
            : 'Porque viste contenido de $g';

        results[id] = RecommendationItem(
          channel: candidate,
          reason: reason,
          category: 'history',
          score: 10.0 + count.toDouble(),
        );
      }
    }

    // Pista 2: Basado en favoritos
    for (final candidate in safeCandidates) {
      final id = candidate.stableTitleId ?? candidate.name;
      if (favoriteIds.contains(id)) continue; // No recomendar el favorito mismo

      final g = candidate.genre?.trim();
      if (g != null && favoriteGenres.containsKey(g)) {
        final count = favoriteGenres[g]!;
        final current = results[id];
        final newScore = 8.0 + count.toDouble();

        if (current == null || newScore > current.score) {
          results[id] = RecommendationItem(
            channel: candidate,
            reason: 'Basado en tus favoritos de $g',
            category: 'favorite',
            score: newScore,
          );
        }
      }
    }

    // Pista 3: Destacados / Top Rated (para completar recomendaciones y arranque en frío)
    for (final candidate in safeCandidates) {
      final id = candidate.stableTitleId ?? candidate.name;
      if (results.containsKey(id)) continue;

      if (candidate.isFeatured) {
        results[id] = RecommendationItem(
          channel: candidate,
          reason: 'Destacado en HourTV',
          category: 'featured',
          score: 5.0,
        );
      } else {
        final ratingVal = double.tryParse(candidate.rating ?? '') ?? 0.0;
        if (ratingVal >= 7.5) {
          results[id] = RecommendationItem(
            channel: candidate,
            reason: 'Mejor valorado en HourTV (${candidate.rating})',
            category: 'top_rated',
            score: 3.0 + (ratingVal / 10.0),
          );
        }
      }
    }

    // Si aún quedan cupos, agregar el resto de candidatos seguros
    if (results.length < limit) {
      for (final candidate in safeCandidates) {
        final id = candidate.stableTitleId ?? candidate.name;
        if (!results.containsKey(id)) {
          results[id] = RecommendationItem(
            channel: candidate,
            reason: 'Recomendado para ti',
            category: 'general',
            score: 1.0,
          );
          if (results.length >= limit) break;
        }
      }
    }

    final sorted = results.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return sorted.take(limit).toList();
  }
}
