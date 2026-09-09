import '../models/channel.dart';

/// Servicio y utilidades para la extracción, limpieza, deduplicación y
/// filtrado de géneros en el catálogo y buscador de HourTV.
class HourTvGenreService {
  const HourTvGenreService._();

  static const defaultGenre = 'Todos los géneros';

  static final RegExp _delimiterRegex = RegExp(r'[,/|;•\\]+');

  static final Set<String> _blacklist = {
    // Tipos de contenido
    'todo',
    'todos',
    'todas',
    'all',
    'pelicula',
    'peliculas',
    'movie',
    'movies',
    'film',
    'films',
    'cine',
    'serie',
    'series',
    'show',
    'shows',
    'tv',
    'tv show',
    'tv shows',
    'live',
    'en vivo',
    'canal',
    'canales',
    'channel',
    'channels',
    'vod',
    'iptv',
    'anime',
    'animes',
    'novela',
    'novelas',
    'telenovela',
    'telenovelas',
    'radio',
    'podcast',

    // Basura técnica y codecs
    '4k',
    'uhd',
    'fhd',
    'hd',
    'sd',
    '720p',
    '1080p',
    '2160p',
    '480p',
    'hevc',
    'h264',
    'h265',
    'x264',
    'x265',
    'aac',
    'ac3',
    'mp3',
    'mp4',
    'mkv',
    'avi',
    'cam',
    'camrip',
    'ts',
    'telesync',
    'hdrip',
    'web dl',
    'webdl',
    'web rip',
    'webrip',
    'bluray',
    'dvd',
    'dvdrip',

    // Etiquetas de audio / idioma
    'latino',
    'castellano',
    'subtitulado',
    'sub',
    'subs',
    'dual',
    'ingles',
    'english',
    'espanol',
    'spanish',
    'multi',
    'audio latino',
    'audio castellano',

    // Marcadores genéricos y categorías basura
    'null',
    'undefined',
    'n a',
    'na',
    'none',
    'unknown',
    'desconocido',
    'otro',
    'otros',
    'general',
    'varios',
    'default',
    'destacados',
    'estrenos',
    'top',
    'favoritos',
    'recientes',
    'populares',
    'trending',
    'sin categoria',
    'sin genero',
    'no category',
    'uncategorized',
    'vip',
    'premium',
    'test',
    'prueba',
    'demo',
  };

  /// Normaliza una cadena para comparaciones sin mayúsculas, acentos ni
  /// caracteres especiales.
  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâã]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöôõ]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static final Set<String> _countryBlacklist = {
    ...kCountryNames.keys.map(normalize),
    ...kCountryNames.values.map(normalize),
    ...kCountryNameToCode.keys.map(normalize),
  };

  /// Comprueba si un token es un valor técnico, tipo o categoría basura.
  static bool isJunkGenre(String token) {
    final clean = token.trim();
    if (clean.length <= 1) return true;
    // Solo dígitos (ej. años 2024, números 123)
    if (RegExp(r'^\d+$').hasMatch(clean)) return true;
    // URLs o nombres de dominio
    if (clean.contains('http://') ||
        clean.contains('https://') ||
        clean.contains('.com') ||
        clean.contains('.m3u') ||
        clean.contains('.mp4')) {
      return true;
    }

    final normalized = normalize(clean);
    if (normalized.isEmpty || normalized.length <= 1) return true;
    if (_blacklist.contains(normalized)) return true;
    if (_countryBlacklist.contains(normalized)) return true;

    final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.any((w) =>
        w == 'canal' ||
        w == 'canales' ||
        w == 'channel' ||
        w == 'channels' ||
        w == 'vip' ||
        w == 'premium' ||
        w == 'pack')) {
      return true;
    }

    if (words.every((w) =>
        RegExp(r'^\d+$').hasMatch(w) ||
        _blacklist.contains(w) ||
        _countryBlacklist.contains(w))) {
      return true;
    }

    return false;
  }

  /// Limpia y da formato legible al nombre de género conservando acentos.
  static String formatDisplayGenre(String raw) {
    var cleaned = raw
        .trim()
        .replaceAll(RegExp(r"""^[\[\(*"'\-\s]+"""), '')
        .replaceAll(RegExp(r"""[\]\)*"'\-\s]+$"""), '')
        .trim();

    if (cleaned.isEmpty) return cleaned;

    // Si viene todo en mayúsculas o todo en minúsculas, capitaliza cada palabra
    // respetando términos especiales como Sci-Fi.
    final isAllUpper =
        cleaned == cleaned.toUpperCase() && cleaned != cleaned.toLowerCase();
    final isAllLower = cleaned == cleaned.toLowerCase();

    if (isAllUpper || isAllLower) {
      cleaned = cleaned
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((word) {
            if (word.toLowerCase() == 'sci-fi') return 'Sci-Fi';
            if (word.toLowerCase() == 'de' ||
                word.toLowerCase() == 'la' ||
                word.toLowerCase() == 'el' ||
                word.toLowerCase() == 'y') {
              return word.toLowerCase();
            }
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          })
          .join(' ');
      // Asegurar que la primera letra del string completo sea mayúscula
      if (cleaned.isNotEmpty) {
        cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
      }
    }

    return cleaned;
  }

  /// Vocabulario normalizado de géneros reconocidos y sus alias comunes
  /// (español e inglés) para validar tokens provenientes de Channel.group.
  static final Map<String, String> _recognizedGroupGenres = {
    // Acción
    'accion': 'Acción',
    'action': 'Acción',

    // Aventura
    'aventura': 'Aventura',
    'aventuras': 'Aventura',
    'adventure': 'Aventura',
    'adventures': 'Aventura',

    // Animación
    'animacion': 'Animación',
    'animation': 'Animación',
    'animated': 'Animación',
    'dibujos animados': 'Animación',

    // Comedia
    'comedia': 'Comedia',
    'comedias': 'Comedia',
    'comedy': 'Comedia',

    // Drama
    'drama': 'Drama',
    'dramas': 'Drama',
    'dramatico': 'Drama',
    'dramatica': 'Drama',

    // Terror / Horror
    'terror': 'Terror',
    'horror': 'Terror',

    // Suspenso / Thriller
    'suspenso': 'Suspenso',
    'suspense': 'Suspenso',
    'thriller': 'Suspenso',
    'thrillers': 'Suspenso',

    // Ciencia Ficción
    'ciencia ficcion': 'Ciencia Ficción',
    'sci fi': 'Ciencia Ficción',
    'scifi': 'Ciencia Ficción',
    'science fiction': 'Ciencia Ficción',

    // Fantasía
    'fantasia': 'Fantasía',
    'fantasy': 'Fantasía',

    // Crimen
    'crimen': 'Crimen',
    'crime': 'Crimen',
    'criminal': 'Crimen',

    // Misterio
    'misterio': 'Misterio',
    'mystery': 'Misterio',

    // Documental
    'documental': 'Documental',
    'documentales': 'Documental',
    'documentary': 'Documental',
    'documentaries': 'Documental',
    'doc': 'Documental',

    // Romance
    'romance': 'Romance',
    'romantica': 'Romance',
    'romantico': 'Romance',
    'romantic': 'Romance',

    // Familiar
    'familiar': 'Familiar',
    'familia': 'Familiar',
    'family': 'Familiar',
    'infantil': 'Familiar',
    'infantiles': 'Familiar',
    'kids': 'Familiar',

    // Bélica / Guerra
    'belica': 'Bélica',
    'belico': 'Bélica',
    'guerra': 'Bélica',
    'war': 'Bélica',

    // Historia
    'historia': 'Historia',
    'historico': 'Historia',
    'historica': 'Historia',
    'history': 'Historia',
    'historical': 'Historia',

    // Musical
    'musical': 'Musical',
    'musicales': 'Musical',
    'musica': 'Musical',
    'music': 'Musical',

    // Western
    'western': 'Western',
    'westerns': 'Western',
    'del oeste': 'Western',
    'oeste': 'Western',

    // Policial
    'policial': 'Policial',
    'policiaco': 'Policial',
    'police': 'Policial',
    'detective': 'Policial',

    // Biografía
    'biografia': 'Biografía',
    'biografico': 'Biografía',
    'biografica': 'Biografía',
    'biography': 'Biografía',
    'biopic': 'Biografía',

    // Deportes
    'deporte': 'Deportes',
    'deportes': 'Deportes',
    'sport': 'Deportes',
    'sports': 'Deportes',

    // Noticias
    'noticias': 'Noticias',
    'news': 'Noticias',
  };

  /// Resuelve un token de grupo a un género reconocido canónico, o null si no es un género válido.
  static String? resolveRecognizedGenre(String token) {
    final norm = normalize(token);
    if (norm.isEmpty) return null;
    return _recognizedGroupGenres[norm];
  }

  /// Extrae los géneros válidos de un elemento único de contenido.
  static Set<String> extractItemGenres(Channel item) {
    final result = <String>{};

    void processString(String? text, {bool isGroup = false}) {
      if (text == null || text.trim().isEmpty) return;

      final parts = text.split(_delimiterRegex);
      for (final rawPart in parts) {
        if (isGroup) {
          final recognized = resolveRecognizedGenre(rawPart);
          if (recognized != null && !isJunkGenre(recognized)) {
            result.add(recognized);
          }
          continue;
        }

        final candidate = formatDisplayGenre(rawPart);
        if (candidate.isEmpty) continue;
        if (isJunkGenre(candidate)) continue;
        result.add(candidate);
      }
    }

    // 1. Channel.genre
    processString(item.genre);

    // 2. Channel.categories
    for (final cat in item.categories) {
      processString(cat);
    }

    // 3. Channel.group (solamente si cada token individual es reconocible como género)
    processString(item.group, isGroup: true);

    return result;
  }

  /// Deduplica y ordena la lista de géneros disponibles para un conjunto
  /// de contenidos, anteponiendo siempre 'Todos los géneros'.
  static List<String> getAvailableGenres(Iterable<Channel> content) {
    // Mapa: key normalizada -> mejor representación visible (con acentos/mayúsculas)
    final genreMap = <String, String>{};

    for (final item in content) {
      final genres = extractItemGenres(item);
      for (final g in genres) {
        final key = normalize(g);
        if (key.isEmpty) continue;

        final existing = genreMap[key];
        if (existing == null) {
          genreMap[key] = g;
        } else if (_isMoreReadable(g, existing)) {
          genreMap[key] = g;
        }
      }
    }

    final sorted = genreMap.values.toList()
      ..sort((a, b) => normalize(a).compareTo(normalize(b)));

    return [defaultGenre, ...sorted];
  }

  /// Determina si una versión de género es más legible (más acentos o mejor capitalizada).
  static bool _isMoreReadable(String candidate, String current) {
    final candidateAccents =
        RegExp(r'[áéíóúÁÉÍÓÚñÑ]').allMatches(candidate).length;
    final currentAccents = RegExp(r'[áéíóúÁÉÍÓÚñÑ]').allMatches(current).length;

    if (candidateAccents > currentAccents) return true;
    if (candidateAccents < currentAccents) return false;

    // Si candidate tiene mayúsculas y current era minúscula
    if (candidate != candidate.toLowerCase() &&
        current == current.toLowerCase()) {
      return true;
    }
    return false;
  }

  /// Comprueba si un canal coincide con el género seleccionado.
  static bool channelMatchesGenre(Channel item, String selectedGenre) {
    if (selectedGenre == defaultGenre ||
        selectedGenre == 'Todo' ||
        selectedGenre.isEmpty) {
      return true;
    }

    final targetKey = normalize(selectedGenre);
    final itemGenres = extractItemGenres(item);

    for (final g in itemGenres) {
      if (normalize(g) == targetKey) return true;
    }

    return false;
  }
}
