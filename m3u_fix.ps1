# Write m3u_parser_service.dart correctly
# Run: powershell -ExecutionPolicy Bypass -File m3u_fix.ps1

$m3uContent = @"
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/m3u_list.dart';

class M3UParserService {
  static List<Channel> parseM3U(String content, {String? listName}) {
    final List<Channel> channels = [];
    final lines = content.split('\n');
    String? currentName;
    Map<String, String> currentAttributes = {};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTM3U')) continue;
      if (line.startsWith('#EXTINF:')) {
        currentAttributes = _parseExtInf(line.substring(8));
        if (i + 1 < lines.length) currentName = lines[i + 1].trim();
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        final url = line;
        if (currentName != null && currentName.isNotEmpty) {
          final channel = Channel.fromM3U(currentName, url, currentAttributes);
          if (listName != null) channel.category = listName;
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
    final attrRegex = RegExp(r'([\w-]+)=["\x27]([^"\x27]*)["\x27]|([\w-]+)=(\S+)');
    for (final match in attrRegex.allMatches(attrsPart)) {
      final key = match.group(1) ?? match.group(3);
      final value = match.group(2) ?? match.group(4);
      if (key != null && value != null) attrs[key] = value;
    }
    return attrs;
  }

  static Future<List<Channel>> fetchAndParse(String url, {String? listName}) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 30), onTimeout: () => throw Exception('Tiempo de espera agotado'));
      if (response.statusCode == 200) return parseM3U(_decodeContent(response), listName: listName);
      else throw Exception('Error HTTP: ' + response.statusCode.toString());
    } catch (e) { throw Exception('Error al cargar M3U: ' + e.toString()); }
  }

  static String _decodeContent(http.Response response) {
    try { return utf8.decode(response.bodyBytes, allowMalformed: true); } catch (_) { return latin1.decode(response.bodyBytes); }
  }

  static List<M3UList> getDefaultLists() {
    return [
      M3UList(name: 'Latinos', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/countries/mx.m3u', description: 'Canales latinoamericanos', category: 'latinos', isDefault: true),
      M3UList(name: 'Espana', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/countries/es.m3u', description: 'Canales Espanoles', category: 'espana', isDefault: true),
      M3UList(name: 'USA', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/countries/us.m3u', description: 'Canales americanos', category: 'usa', isDefault: true),
      M3UList(name: 'Deportes', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/categories/sports.m3u', description: 'Canales deportivos', category: 'deportes', isDefault: true),
      M3UList(name: 'Peliculas', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/categories/movies.m3u', description: 'Canales de cine', category: 'peliculas', isDefault: true),
      M3UList(name: 'Infantiles', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/categories/kids.m3u', description: 'Canales para ninos', category: 'infantiles', isDefault: true),
      M3UList(name: 'Musica', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/categories/music.m3u', description: 'Canales musicales', category: 'musica', isDefault: true),
      M3UList(name: 'Noticias', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/categories/news.m3u', description: 'Canales de noticias', category: 'noticias', isDefault: true),
      M3UList(name: 'Documentales', url: 'https://raw.githubusercontent.com/iptv-org/iptv/master/data/categories/documentary.m3u', description: 'Canales documentales', category: 'documentales', isDefault: true),
    ];
  }
}
"@

[System.IO.File]::WriteAllText("C:\Users\Kleiner\proyectos\mi_app\lib\services\m3u_parser_service.dart", $m3uContent, [System.Text.Encoding]::UTF8)
Write-Host "m3u_parser_service.dart written successfully!"