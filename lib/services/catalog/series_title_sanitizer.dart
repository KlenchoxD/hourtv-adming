/// Sanitizador de presentación para títulos de series.
///
/// REGLA ESTRICTA DE ARQUITECTURA:
/// - Es exclusivamente de presentación visual en la UI.
/// - NUNCA modifica IDs, URLs, claves de progreso, favoritos, relaciones DB ni datos persistidos.
/// - CONSERVA SIEMPRE la información legítima: título, temporada ("Temporada X", "Season Y", "T1") y año ("(2024)").
/// - RETIRA ÚNICAMENTE sufijos evidentes de sitios web, scrapers (ej. "| Blog de Pelis", "| Cuevana") y basura técnica ("[1080p]").
class SeriesTitleSanitizer {
  SeriesTitleSanitizer._();

  static final RegExp _technicalBracketsRegex = RegExp(
    r'\[[^\]]*(?:1080p|720p|480p|4k|uhd|dual|latino|castellano|subtitulado|sub|hd-rip|hdrip|web-dl|webrip|x264|x265|hevc|bluray|dvdrip)[^\]]*\]',
    caseSensitive: false,
  );

  static final RegExp _technicalParensRegex = RegExp(
    r'\((?!\d{4}\))[^\)]*(?:1080p|720p|480p|4k|uhd|dual|latino|castellano|subtitulado|sub|hd-rip|hdrip|web-dl|webrip|x264|x265|hevc|bluray|dvdrip)[^\)]*\)',
    caseSensitive: false,
  );

  static final RegExp _scraperBrandRegex = RegExp(
    r'(?:\||-|–|—)\s*(?:Blog de Pelis|CineCalidad|Cuevana(?:\s*\d+)?|PelisPlus|PelisPedia|Repelis|Gnula|VerPelis|SeriesGato|Series24|AnimeFLV|JKAnime)[^|–—\-]*',
    caseSensitive: false,
  );

  static final RegExp _domainRegex = RegExp(
    r'(?:\||-|–|—)?\s*[a-zA-Z0-9\-]+\.(?:com|net|org|io|me|tv|to|is|video|lat|app)\b',
    caseSensitive: false,
  );

  static final RegExp _trailingPunctuation = RegExp(
    r'[\s|\-–—:]+$',
  );

  /// Devuelve el título limpio para presentación en pantalla preservando temporadas y años.
  static String sanitize(String rawTitle) {
    if (rawTitle.trim().isEmpty) return rawTitle;

    var cleaned = rawTitle;

    // 1. Eliminar sufijos de marcas conocidas de sitios web
    cleaned = cleaned.replaceAll(_scraperBrandRegex, '');

    // 2. Eliminar dominios web remanentes
    cleaned = cleaned.replaceAll(_domainRegex, '');

    // 3. Eliminar etiquetas técnicas entre corchetes
    cleaned = cleaned.replaceAll(_technicalBracketsRegex, '');

    // 4. Eliminar etiquetas técnicas entre paréntesis que no sean año
    cleaned = cleaned.replaceAll(_technicalParensRegex, '');

    // 5. Normalizar espacios repetidos
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // 6. Eliminar separadores colgantes al final
    cleaned = cleaned.replaceAll(_trailingPunctuation, '').trim();

    return cleaned.isNotEmpty ? cleaned : rawTitle.trim();
  }
}
