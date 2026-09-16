import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';
import 'package:streamtv/services/catalog/catalog_repository.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';

void main() {
  group('CatalogResolutionPolicy in HourTvMobileSearch', () {
    late CatalogDatabase db;

    setUp(() {
      db = CatalogDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Empty Drift falls back to in-memory JSON catalog covering all items', (tester) async {
      final repo = CatalogRepository(dao: db.catalogDao);

      // JSON items
      final jsonItems = List.generate(
        15,
        (i) => Channel(
          name: 'Pelicula JSON $i',
          url: 'https://example.com/movie_$i.mp4',
          logo: 'https://example.com/logo_$i.jpg',
          forcedType: 'movie',
          category: 'peliculas',
        ),
      );

      final pageSource = CatalogPageSource(dao: db.catalogDao);
      // Not yet populated, so items is empty
      expect(pageSource.items, isEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourTvMobileSearch(
              content: jsonItems,
              catalogRepository: repo,
              catalogPageSource: pageSource,
              onOpen: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that items from the JSON fallback are visible in the search UI
      expect(find.text('Pelicula JSON 0'), findsOneWidget);
      expect(find.text('Pelicula JSON 1'), findsOneWidget);
    });
  });
}
