import 'dart:convert';
import 'dart:io';
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/services/catalog_parser.dart';

void main() {
  test('Verify exact counts populated into Drift match sources.json', () async {
    final db = CatalogDatabase(NativeDatabase.memory());
    final repo = CatalogRepository(dao: db.catalogDao);

    // Initial Drift counts are 0
    expect(await repo.countMovies(), equals(0));
    expect(await repo.countSeries(), equals(0));
    expect(await repo.countEpisodes(), equals(0));
    expect(await repo.countSources(), equals(0));

    final file = File('assets/data/sources.json');
    final json = jsonDecode(file.readAsStringSync());
    final payload = CatalogParser.parse(json);

    await repo.populateFromPayload(payload);

    final driftMovies = await repo.countMovies();
    final driftSeries = await repo.countSeries();
    final driftEpisodes = await repo.countEpisodes();
    final driftSources = await repo.countSources();

    print('=== DRIFT POPULATED COUNTS ===');
    print('Drift Movies: $driftMovies');
    print('Drift Series: $driftSeries');
    print('Drift Episodes: $driftEpisodes');
    print('Drift Sources: $driftSources');
    print('==============================');

    expect(driftMovies, equals(222));
    expect(driftSeries, equals(53));
    expect(driftEpisodes, equals(496));
    expect(driftSources, equals(776));

    await db.close();
  });
}
