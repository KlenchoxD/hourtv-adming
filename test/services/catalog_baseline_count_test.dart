import 'dart:convert';
import 'dart:io';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/catalog_parser.dart';

void main() {
  test('Count baseline catalog items from sources.json via CatalogParser', () {
    final file = File('assets/data/sources.json');
    expect(file.existsSync(), isTrue, reason: 'assets/data/sources.json must exist');
    final json = jsonDecode(file.readAsStringSync());
    final payload = CatalogParser.parse(json);

    final movies = payload.channels.where((c) => c.forcedType == 'movie' || c.category == 'peliculas').toList();
    final live = payload.channels.where((c) => c.forcedType != 'movie' && c.category != 'peliculas').toList();
    final series = payload.series;

    int episodeCount = 0;
    int movieSources = 0;
    int seriesSources = 0;

    for (final m in movies) {
      movieSources += (m.servers.isNotEmpty ? m.servers.length : (m.url.isNotEmpty ? 1 : 0));
    }

    for (final s in series) {
      final eps = s.episodes ?? [];
      episodeCount += eps.length;
      for (final ep in eps) {
        seriesSources += (ep.servers.isNotEmpty ? ep.servers.length : (ep.url.isNotEmpty ? 1 : 0));
      }
    }

    print('=== BASELINE CATALOG COUNTS (sources.json) ===');
    print('Movies: ${movies.length}');
    print('Series: ${series.length}');
    print('Episodes: $episodeCount');
    print('Live Channels: ${live.length}');
    print('Movie Sources: $movieSources');
    print('Series Sources: $seriesSources');
    print('Total VOD Sources: ${movieSources + seriesSources}');
    print('Total Channels in Payload: ${payload.channels.length}');
    print('==============================================');

    expect(movies.length, greaterThan(0));
    expect(series.length, greaterThan(0));
    expect(episodeCount, greaterThan(0));
  });
}
