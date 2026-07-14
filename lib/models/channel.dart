import 'epg_program.dart';

/// Tipo de contenido. En vivo = TV en directo; pelicula/serie = bajo demanda (VOD).
enum MediaType { live, movie, series }

/// Codigo ISO de pais -> nombre en español. Usado para agrupar EN VIVO por país.
const Map<String, String> kCountryNames = {
  'co': 'Colombia',
  'mx': 'México',
  'ar': 'Argentina',
  'cl': 'Chile',
  'pe': 'Perú',
  've': 'Venezuela',
  'es': 'España',
  'us': 'Estados Unidos',
  'ec': 'Ecuador',
  'uy': 'Uruguay',
  'py': 'Paraguay',
  'bo': 'Bolivia',
  'cr': 'Costa Rica',
  'pa': 'Panamá',
  'do': 'Rep. Dominicana',
  'gt': 'Guatemala',
  'hn': 'Honduras',
  'sv': 'El Salvador',
  'ni': 'Nicaragua',
  'pr': 'Puerto Rico',
  'cu': 'Cuba',
  'br': 'Brasil',
  'pt': 'Portugal',
  'ca': 'Canadá',
  'gb': 'Reino Unido',
  'uk': 'Reino Unido',
  'fr': 'Francia',
  'it': 'Italia',
  'de': 'Alemania',
  'gq': 'Guinea Ecuatorial',
};

/// Nombre de pais (ingles/español, como llega en group-title de algunas listas)
/// -> codigo ISO, para deducir el pais cuando no hay sufijo en el tvg-id.
const Map<String, String> kCountryNameToCode = {
  'colombia': 'co',
  'argentina': 'ar',
  'mexico': 'mx',
  'méxico': 'mx',
  'chile': 'cl',
  'peru': 'pe',
  'perú': 'pe',
  'venezuela': 've',
  'spain': 'es',
  'españa': 'es',
  'ecuador': 'ec',
  'uruguay': 'uy',
  'paraguay': 'py',
  'bolivia': 'bo',
  'costa rica': 'cr',
  'panama': 'pa',
  'panamá': 'pa',
  'dominican republic': 'do',
  'república dominicana': 'do',
  'guatemala': 'gt',
  'honduras': 'hn',
  'el salvador': 'sv',
  'nicaragua': 'ni',
  'puerto rico': 'pr',
  'cuba': 'cu',
  'brazil': 'br',
  'brasil': 'br',
  'portugal': 'pt',
  'united states': 'us',
  'usa': 'us',
  'estados unidos': 'us',
  'canada': 'ca',
  'canadá': 'ca',
  'united kingdom': 'gb',
  'uk': 'gb',
};

/// Emoji de bandera a partir del codigo ISO de 2 letras.
String countryFlag(String? code) {
  if (code == null || code.length != 2) return '🌎';
  final cc = code.toUpperCase();
  final a = cc.codeUnitAt(0), b = cc.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '🌎';
  return String.fromCharCode(0x1F1E6 + a - 65) +
      String.fromCharCode(0x1F1E6 + b - 65);
}

class Channel {
  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  String? countryCode; // codigo ISO del pais (para agrupar EN VIVO)
  String? category; // categoria de origen (ej: 'peliculas')
  String? genre; // genero asignado por la lista (deportes, anime...)
  String? forcedType; // 'movie' | 'series' para VOD que no se detecta por URL
  bool isFavorite;
  DateTime? lastWatched;
  EpgProgram? currentProgram;
  EpgProgram? nextProgram;
  String? plot;
  String? year;
  String? rating;
  String? duration;
  String? cast; // actores principales, separados por coma (TMDB/Xtream)
  String? director;
  String? backdrop; // imagen horizontal 16:9 para cabeceras (TMDB)
  String? userAgent; // User-Agent de la fuente (streams que rechazan el UA por defecto)

  Channel({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    this.tvgId,
    this.tvgName,
    this.countryCode,
    this.category,
    this.genre,
    this.forcedType,
    this.isFavorite = false,
    this.lastWatched,
    this.currentProgram,
    this.nextProgram,
    this.plot,
    this.year,
    this.rating,
    this.duration,
    this.cast,
    this.director,
    this.backdrop,
    this.userAgent,
  });

  factory Channel.fromM3U(
    String name,
    String url,
    Map<String, String> attributes,
  ) {
    return Channel(
      name: name,
      url: url,
      logo: attributes['tvg-logo'],
      group: attributes['group-title'],
      tvgId: attributes['tvg-id'],
      tvgName: attributes['tvg-name'],
      countryCode: _deduceCountry(attributes),
    );
  }

  /// Deduce el pais: primero el sufijo del tvg-id (ej "CaracolTV.co" -> co),
  /// luego el group-title si coincide con un nombre de pais conocido.
  static String? _deduceCountry(Map<String, String> a) {
    final id = a['tvg-id'] ?? '';
    // Formato real de iptv-org: "NombreCanal.<pais>@<calidad>" (ej "12tv.es@SD",
    // "NatureTime.ca@ES"). El código de país va tras el ÚLTIMO punto y antes de @.
    if (id.contains('.')) {
      var suffix = id.split('.').last.toLowerCase();
      final at = suffix.indexOf('@');
      if (at >= 0) suffix = suffix.substring(0, at);
      suffix = suffix.trim();
      if (suffix.length == 2 &&
          RegExp(r'^[a-z]{2}$').hasMatch(suffix) &&
          kCountryNames.containsKey(suffix)) {
        return suffix;
      }
    }
    final g = (a['group-title'] ?? '').toLowerCase().trim();
    if (kCountryNameToCode.containsKey(g)) return kCountryNameToCode[g];
    final country = (a['country'] ?? '').toLowerCase().trim();
    if (country.length == 2 && kCountryNames.containsKey(country)) {
      return country;
    }
    if (kCountryNameToCode.containsKey(country)) {
      return kCountryNameToCode[country];
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'logo': logo,
    'group': group,
    'tvgId': tvgId,
    'tvgName': tvgName,
    'countryCode': countryCode,
    'category': category,
    'genre': genre,
    'forcedType': forcedType,
    'isFavorite': isFavorite,
    'lastWatched': lastWatched?.toIso8601String(),
    'plot': plot,
    'year': year,
    'rating': rating,
    'duration': duration,
    'cast': cast,
    'director': director,
    'backdrop': backdrop,
    'userAgent': userAgent,
  };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    name: json['name'] ?? '',
    url: json['url'] ?? '',
    logo: json['logo'],
    group: json['group'],
    tvgId: json['tvgId'],
    tvgName: json['tvgName'],
    countryCode: json['countryCode'],
    category: json['category'],
    genre: json['genre'],
    forcedType: json['forcedType'],
    isFavorite: json['isFavorite'] ?? false,
    lastWatched: json['lastWatched'] != null
        ? DateTime.tryParse(json['lastWatched'])
        : null,
    plot: json['plot']?.toString(),
    year: json['year']?.toString(),
    rating: json['rating']?.toString(),
    duration: json['duration']?.toString(),
    cast: json['cast']?.toString(),
    director: json['director']?.toString(),
    backdrop: json['backdrop']?.toString(),
    userAgent: json['userAgent']?.toString(),
  );

  Channel copyWith({
    String? name,
    String? url,
    String? logo,
    String? group,
    String? tvgId,
    String? tvgName,
    String? countryCode,
    String? category,
    String? genre,
    String? forcedType,
    bool? isFavorite,
    DateTime? lastWatched,
    EpgProgram? currentProgram,
    EpgProgram? nextProgram,
    String? plot,
    String? year,
    String? rating,
    String? duration,
    String? cast,
    String? director,
    String? backdrop,
    String? userAgent,
  }) {
    return Channel(
      name: name ?? this.name,
      url: url ?? this.url,
      logo: logo ?? this.logo,
      group: group ?? this.group,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      countryCode: countryCode ?? this.countryCode,
      category: category ?? this.category,
      genre: genre ?? this.genre,
      forcedType: forcedType ?? this.forcedType,
      isFavorite: isFavorite ?? this.isFavorite,
      lastWatched: lastWatched ?? this.lastWatched,
      currentProgram: currentProgram ?? this.currentProgram,
      nextProgram: nextProgram ?? this.nextProgram,
      plot: plot ?? this.plot,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      duration: duration ?? this.duration,
      cast: cast ?? this.cast,
      director: director ?? this.director,
      backdrop: backdrop ?? this.backdrop,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  String? get countryName =>
      countryCode == null ? null : kCountryNames[countryCode];
  String get countryFlagEmoji => countryFlag(countryCode);
  String? get nowTitle => currentProgram?.title;
  String? get nextTitle => nextProgram?.title;
  String? get epgLine {
    final current = currentProgram;
    if (current != null) return '${current.timeRange}  ${current.title}';
    final next = nextProgram;
    if (next != null) return 'Luego ${next.timeRange}  ${next.title}';
    return null;
  }

  /// Nombre limpio para mostrar: sin URLs, sin etiquetas de calidad/estado
  /// entre corchetes [..] ni paréntesis (..). Asi EN VIVO muestra solo el
  /// nombre del canal, como MagisTV/Netflix.
  String get displayName {
    var n = (tvgName != null && tvgName!.trim().isNotEmpty)
        ? tvgName!.trim()
        : name.trim();
    if (n.startsWith('http://') || n.startsWith('https://')) n = '';
    // Quitar [corchetes] y (paréntesis) completos (calidad, estado, idioma...)
    n = n.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    n = n.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    // Marcadores sueltos de calidad
    n = n.replaceAll(
      RegExp(
        r'\b(FHD|UHD|HD|SD|4K|H\.?265|H\.?264|1080p?|720p?|480p?)\b',
        caseSensitive: false,
      ),
      '',
    );
    n = n.replaceAll(RegExp(r'[•|]+'), ' ');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    n = n.replaceAll(RegExp(r'^[-–·\s]+|[-–·\s]+$'), '').trim();
    if (n.isEmpty) {
      final base = name.trim();
      return (base.isEmpty || base.startsWith('http')) ? 'Canal' : base;
    }
    return n;
  }

  String get displayGroup => group ?? 'Sin categoría';

  /// Detecta si es TV en vivo, pelicula o serie SOLO por la ruta del stream.
  MediaType get type {
    if (forcedType == 'movie') return MediaType.movie;
    if (forcedType == 'series') return MediaType.series;
    final u = url.toLowerCase();
    if (u.contains('/movie/') || u.contains('/movies/')) return MediaType.movie;
    if (u.contains('/series/')) return MediaType.series;
    return MediaType.live;
  }

  /// Nombre base de la serie sin el sufijo de temporada/episodio.
  String get seriesTitle {
    var n = displayName;
    n = n.replaceAll(
      RegExp(r'\s*[\(\[]?S\d{1,2}\s*E\d{1,3}[\)\]]?', caseSensitive: false),
      '',
    );
    n = n.replaceAll(RegExp(r'\s*\d{1,2}x\d{1,3}', caseSensitive: false), '');
    n = n.replaceAll(RegExp(r'\s*-\s*$'), '');
    return n.trim().isEmpty ? displayName : n.trim();
  }
}
