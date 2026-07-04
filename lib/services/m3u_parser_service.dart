import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/m3u_list.dart';

class M3UParserService {
  static List<Channel> parseM3U(String content, {String? listName, String? genre, String? mediaType}) {
    final List<Channel> channels = [];
    final lines = content.split('\n');
    String? currentName;
    Map<String, String> currentAttributes = {};
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTM3U')) continue;
      if (line.startsWith('#EXTINF:')) {
        currentAttributes = _parseExtInf(line.substring(8));
        // El nombre real esta despues de la coma en el #EXTINF (o en tvg-name),
        // NUNCA es la linea siguiente (esa es la URL del stream).
        final extName = currentAttributes['_name'] ?? '';
        currentName = extName.isNotEmpty ? extName : (currentAttributes['tvg-name'] ?? '');
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (currentName != null) {
          final name = currentName.isNotEmpty ? currentName : 'Canal';
          final channel = Channel.fromM3U(name, line, currentAttributes);
          if (listName != null) channel.category = listName;
          if (genre != null) channel.genre = genre;
          if (mediaType == 'movie' || mediaType == 'series') channel.forcedType = mediaType;
          channels.add(channel);
        }
        currentName = null;
        currentAttributes = {};
      }
    }
    return channels;
  }

  static Map<String, String> _parseExtInf(String info) {
    final Map<String, String> attrs = {};
    final commaIndex = info.indexOf(',');
    String attrsPart = commaIndex > 0 ? info.substring(0, commaIndex) : info;
    if (commaIndex > 0) attrs['_name'] = info.substring(commaIndex + 1).trim();
    final attrRegex = RegExp(r'([\w-]+)=[\x27"]([^\x27"]*)');
    for (final match in attrRegex.allMatches(attrsPart)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) attrs[key] = value;
    }
    return attrs;
  }

  static Future<List<Channel>> fetchAndParse(String url, {String? listName, String? genre, String? mediaType}) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 30), onTimeout: () => throw Exception('Tiempo de espera agotado'));
      if (response.statusCode == 200) return parseM3U(_decode(response), listName: listName, genre: genre, mediaType: mediaType);
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) { throw Exception('Error cargando M3U: $e'); }
  }

  static String _decode(http.Response r) {
    try { return utf8.decode(r.bodyBytes, allowMalformed: true); } catch (_) { return latin1.decode(r.bodyBytes); }
  }

  /// Listas por defecto (fuente: iptv-org, senales publicas de TV abierta).
  /// El NOMBRE de cada lista define la categoria de sus canales, lo que activa
  /// los filtros del menu lateral. Se cargan en este orden y luego se eliminan
  /// duplicados conservando la primera aparicion (las de genero ganan sobre la
  /// general "Latinos"). 'Peliculas' y 'Series' son canales 24/7 del genero.
  static const String _io = 'https://iptv-org.github.io/iptv';

  /// Solo canales EN VIVO. Las secciones PELICULAS/SERIES se llenan con el VOD
  /// real de la cuenta Xtream del usuario (rutas /movie/ y /series/).
  ///
  /// El campo `category` de cada lista se usa como GENERO del canal:
  ///   'deportes','noticias','infantiles','musica','documentales','anime'
  ///   -> alimentan las categorías tipo Netflix.
  ///   'live' -> canales generales; EN VIVO los agrupa por PAÍS (del tvg-id).
  /// Se cargan en este orden y se deduplican por URL conservando la primera
  /// aparición, por eso los géneros van primero (ganan su etiqueta).
  /// Países (código ISO -> nombre) cuyas listas oficiales de iptv-org se cargan
  /// para EN VIVO. Cada lista trae solo canales de ese país.
  static const Map<String, String> _countries = {
    'co': 'Colombia', 'mx': 'México', 'ar': 'Argentina', 'cl': 'Chile',
    'pe': 'Perú', 've': 'Venezuela', 'es': 'España', 'ec': 'Ecuador',
    'uy': 'Uruguay', 'py': 'Paraguay', 'bo': 'Bolivia', 'cr': 'Costa Rica',
    'pa': 'Panamá', 'do': 'Rep. Dominicana', 'gt': 'Guatemala', 'pr': 'Puerto Rico',
    'us': 'Estados Unidos',
  };

  static List<M3UList> getDefaultLists() => [
    // --- Generos (categorías) primero, para que conserven su etiqueta ---
    M3UList(name: 'Deportes', url: '$_io/categories/sports.m3u', description: 'Canales deportivos', category: 'deportes', isDefault: true),
    M3UList(name: 'Noticias', url: '$_io/categories/news.m3u', description: 'Canales de noticias', category: 'noticias', isDefault: true),
    M3UList(name: 'Infantiles', url: '$_io/categories/kids.m3u', description: 'Canales para niños', category: 'infantiles', isDefault: true),
    M3UList(name: 'Anime', url: '$_io/categories/animation.m3u', description: 'Anime y animación', category: 'anime', isDefault: true),
    M3UList(name: 'Documentales', url: '$_io/categories/documentary.m3u', description: 'Documentales', category: 'documentales', isDefault: true),
    M3UList(name: 'Música', url: '$_io/categories/music.m3u', description: 'Canales musicales', category: 'musica', isDefault: true),
    // --- EN VIVO por PAÍS: lista oficial de cada país (iptv-org/countries) ---
    for (final e in _countries.entries)
      M3UList(name: e.value, url: '$_io/countries/${e.key}.m3u', description: 'Canales de ${e.value}', category: 'live', isDefault: true),
    // --- Refuerzo: agregados grandes (rellenan lo que falte) ---
    M3UList(name: 'Latinos', url: '$_io/languages/spa.m3u', description: 'Canales en español', category: 'live', isDefault: true),
    M3UList(name: 'Free-TV', url: 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8', description: 'Canales por país (Free-TV)', category: 'live', isDefault: true),
  ];
}
