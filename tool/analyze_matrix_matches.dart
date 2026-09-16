import 'dart:convert';
import 'dart:io';

void main() {
  var file = File('catalog.json');
  if (!file.existsSync()) {
    file = File('assets/data/catalog.json');
  }
  if (!file.existsSync()) {
    print('catalog.json no encontrado');
    return;
  }
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final movies = (data['movies'] as List<dynamic>? ?? []);
  final series = (data['series'] as List<dynamic>? ?? []);
  final all = [...movies, ...series];

  print('=== DIAGNÓSTICO MATRIX EN CATALOG.JSON ===');
  print('Total películas: ${movies.length}');
  print('Total series: ${series.length}');
  print('Total títulos en JSON: ${all.length}');

  int exactTitle = 0;
  int prefixTitle = 0;
  int partialTitle = 0;
  int plotMatches = 0;
  int genreMatches = 0;
  int castMatches = 0;

  final matches = <Map<String, dynamic>>[];

  for (final raw in all) {
    final item = raw as Map<String, dynamic>;
    final title = (item['title'] ?? '').toString();
    final originalTitle = (item['original_title'] ?? item['originalTitle'] ?? '').toString();
    final plot = (item['plot'] ?? '').toString();
    final genre = (item['genre'] ?? '').toString();
    final cast = (item['cast'] ?? '').toString();

    final normTitle = title.toLowerCase().trim();
    final normOrig = originalTitle.toLowerCase().trim();
    final normPlot = plot.toLowerCase();
    final normGenre = genre.toLowerCase();
    final normCast = cast.toLowerCase();

    bool isExact = normTitle == 'matrix' || normOrig == 'matrix';
    bool isPrefix = normTitle.startsWith('matrix ') || normTitle.startsWith('matrix:') || normOrig.startsWith('matrix ');
    bool isPartial = !isExact && !isPrefix && (normTitle.contains('matrix') || normOrig.contains('matrix'));
    bool inPlot = normPlot.contains('matrix');
    bool inGenre = normGenre.contains('matrix');
    bool inCast = normCast.contains('matrix');

    if (isExact) exactTitle++;
    if (isPrefix) prefixTitle++;
    if (isPartial) partialTitle++;
    if (inPlot) plotMatches++;
    if (inGenre) genreMatches++;
    if (inCast) castMatches++;

    if (isExact || isPrefix || isPartial || inPlot || inGenre || inCast) {
      matches.add({
        'id': item['id'],
        'title': title,
        'originalTitle': originalTitle,
        'exact': isExact,
        'prefix': isPrefix,
        'partial': isPartial,
        'plot': inPlot,
        'genre': inGenre,
        'cast': inCast,
      });
    }
  }

  print('\nDesglose de coincidencias en JSON:');
  print('- Título exacto: $exactTitle');
  print('- Prefijo en título: $prefixTitle');
  print('- Título parcial: $partialTitle');
  print('- Coincidencia en Plot (sinopsis): $plotMatches');
  print('- Coincidencia en Género: $genreMatches');
  print('- Coincidencia en Reparto: $castMatches');
  print('- Total títulos con alguna coincidencia: ${matches.length}');

  print('\nPrimeros 20 resultados encontrados:');
  for (var i = 0; i < matches.length && i < 20; i++) {
    final m = matches[i];
    final fields = <String>[];
    if (m['exact'] as bool) fields.add('título exacto');
    if (m['prefix'] as bool) fields.add('prefijo');
    if (m['partial'] as bool) fields.add('título parcial');
    if (m['plot'] as bool) fields.add('sinopsis');
    if (m['genre'] as bool) fields.add('género');
    if (m['cast'] as bool) fields.add('reparto');
    print('${i + 1}. [${m['id']}] "${m['title']}" -> campos: ${fields.join(', ')}');
  }
}
