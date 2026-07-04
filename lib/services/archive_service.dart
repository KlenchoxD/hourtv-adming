import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

/// Catálogo de películas de DOMINIO PÚBLICO desde Internet Archive (archive.org).
/// 100% legal y gratis: clásicos, terror, ciencia ficción, animación, etc.
/// Las películas se marcan como VOD (forcedType 'movie') y su stream real se
/// resuelve al reproducir con [resolveStream].
class ArchiveService {
  static const String _img = 'https://archive.org/services/img/';

  /// Categorías (etiqueta visible -> consulta de archive.org). Solo colecciones
  /// de dominio público.
  static const List<(String, String)> categories = [
    ('Clásicos del cine', 'collection:(feature_films) AND mediatype:(movies)'),
    ('Terror', 'collection:(feature_films) AND subject:(horror)'),
    ('Ciencia ficción', 'collection:(feature_films) AND subject:("science fiction")'),
    ('Animación', 'collection:(animationandcartoons) AND mediatype:(movies)'),
    ('Comedia', 'collection:(feature_films) AND subject:(comedy)'),
    ('Cine negro', 'collection:(feature_films) AND subject:("film noir")'),
  ];

  /// Descarga todas las categorías en paralelo y devuelve la lista de películas.
  static Future<List<Channel>> fetchCatalog({int perCategory = 40}) async {
    final results = await Future.wait(
      categories.map((c) => _fetchCategory(c.$1, c.$2, perCategory).catchError((_) => <Channel>[])),
    );
    // Dedup por identificador conservando la primera categoría.
    final seen = <String>{};
    final out = <Channel>[];
    for (final list in results) {
      for (final ch in list) {
        if (seen.add(ch.url)) out.add(ch);
      }
    }
    return out;
  }

  static Future<List<Channel>> _fetchCategory(String label, String query, int rows) async {
    final url = 'https://archive.org/advancedsearch.php?q=${Uri.encodeQueryComponent(query)}'
        '&fl[]=identifier&fl[]=title&fl[]=year&fl[]=description&rows=$rows&sort[]=downloads+desc&output=json';
    final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    List? docs;
    if (data is Map) {
      final resp = data['response'];
      if (resp is Map) docs = resp['docs'] as List?;
    }
    if (docs == null) return [];
    final out = <Channel>[];
    for (final d in docs) {
      if (d is! Map) continue;
      final id = (d['identifier'] ?? '').toString();
      if (id.isEmpty) continue;
      var title = (d['title'] ?? id).toString();
      final year = d['year'];
      if (year != null && year.toString().isNotEmpty && !title.contains(year.toString())) {
        title = '$title ($year)';
      }
      // Sinopsis (puede llegar como String o List). Se guarda en `group` para
      // tenerla disponible (sin tocar el modelo) en una futura ficha de detalle.
      var desc = d['description'];
      if (desc is List) desc = desc.isNotEmpty ? desc.first.toString() : '';
      var synopsis = (desc ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (synopsis.length > 400) synopsis = '${synopsis.substring(0, 400)}…';
      out.add(Channel(
        name: title,
        url: 'archive:$id',
        logo: '$_img$id',
        group: synopsis.isEmpty ? null : synopsis,
        genre: label,
        category: 'peliculas',
        forcedType: 'movie',
      ));
    }
    return out;
  }

  /// Resuelve la URL real de vídeo (.mp4) de un item de archive.org.
  static Future<String?> resolveStream(String archiveUrl) async {
    final id = archiveUrl.startsWith('archive:') ? archiveUrl.substring(8) : archiveUrl;
    try {
      final res = await http.get(Uri.parse('https://archive.org/metadata/$id'), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final files = data is Map ? data['files'] : null;
      if (files is! List) return null;
      String? h264, mpeg4, other;
      for (final f in files) {
        if (f is! Map) continue;
        final name = (f['name'] ?? '').toString();
        final fmt = (f['format'] ?? '').toString().toLowerCase();
        final lower = name.toLowerCase();
        if (!lower.endsWith('.mp4') && !lower.endsWith('.m4v') && !lower.endsWith('.ogv') && !lower.endsWith('.webm')) continue;
        if (fmt.contains('h.264')) { h264 ??= name; }
        else if (fmt.contains('mpeg4')) { mpeg4 ??= name; }
        else { other ??= name; }
      }
      final pick = h264 ?? mpeg4 ?? other;
      if (pick == null) return null;
      return 'https://archive.org/download/$id/${Uri.encodeComponent(pick)}';
    } catch (_) {
      return null;
    }
  }
}
