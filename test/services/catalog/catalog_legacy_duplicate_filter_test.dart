import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/catalog/catalog_legacy_duplicate_filter.dart';

void main() {
  test('hides a weak localized IPTV copy when a curated film exists', () {
    final curated = Channel(
      name: 'Resident Evil III. Extinción',
      url: 'https://catalog.example/resident-evil-3',
      logo: 'https://image.tmdb.org/t/p/w500/poster.jpg',
      year: '2007',
      tmdbId: 7737,
      forcedType: 'movie',
    );
    final legacyCopy = Channel(
      name: 'Resident Evil 3: Extinción',
      url: 'https://iptv.example/watch/legacy',
      category: 'peliculas',
      year: '2007',
      forcedType: 'movie',
    );
    final unmatchedOldMovie = Channel(
      name: 'Resident Evil',
      url: 'https://iptv.example/watch/original',
      category: 'peliculas',
      year: '2002',
      forcedType: 'movie',
    );

    final visible = CatalogLegacyDuplicateFilter.withoutCuratedAliases([
      legacyCopy,
      curated,
      unmatchedOldMovie,
    ]);

    expect(visible.map((channel) => channel.name), [
      'Resident Evil III. Extinción',
      'Resident Evil',
    ]);
  });

  test('removes the legacy Resident Evil copies found in the device cache', () {
    final curated =
        [
          ('Resident Evil: Death Island', '2023', 1083862),
          ('Resident Evil. Bienvenidos a Raccoon City', '2021', 460458),
          ('Resident Evil: El capítulo final', '2016', 173897),
          ('Resident Evil V. Venganza', '2012', 71679),
          ('Resident Evil IV. Ultratumba', '2010', 35791),
          ('Resident Evil III. Extinción', '2007', 7737),
        ].map(
          (entry) => Channel(
            name: entry.$1,
            url: 'https://catalog.example/${entry.$3}',
            logo: 'https://image.tmdb.org/t/p/w500/${entry.$3}.jpg',
            year: entry.$2,
            tmdbId: entry.$3,
            forcedType: 'movie',
          ),
        );
    final legacyNames = [
      ('Resident Evil: Isla de la Muerte', '2023'),
      ('Resident Evil: Bienvenido a Raccoon City', '2021'),
      ('Resident Evil 6: Capítulo final', '2016'),
      ('Resident Evil 5: Venganza', '2012'),
      ('Resident Evil 4: Resurrección', '2010'),
      ('Resident Evil 3: Extinción', '2007'),
    ];
    final legacy = legacyNames.map(
      (entry) => Channel(
        name: entry.$1,
        url: 'https://mp4.nu/${entry.$2}',
        category: 'peliculas',
        year: entry.$2,
        forcedType: 'movie',
      ),
    );
    final original = Channel(
      name: 'Resident Evil',
      url: 'https://mp4.nu/2002',
      category: 'peliculas',
      year: '2002',
      forcedType: 'movie',
    );

    final visible = CatalogLegacyDuplicateFilter.withoutCuratedAliases([
      ...legacy,
      ...curated,
      original,
    ]);

    expect(visible, hasLength(7));
    expect(visible.map((channel) => channel.name), contains('Resident Evil'));
    expect(
      visible.where((channel) => channel.url.startsWith('https://mp4.nu/')),
      hasLength(1),
    );
  });

  test(
    'keeps two fully curated titles even when they share a franchise/year',
    () {
      final titles = [
        Channel(
          name: 'Spider-Man: Homecoming',
          url: 'https://catalog.example/spider-man-homecoming',
          logo: 'https://image.tmdb.org/t/p/w500/homecoming.jpg',
          year: '2017',
          tmdbId: 315635,
          forcedType: 'movie',
        ),
        Channel(
          name: 'Spider-Man: Into the Spider-Verse',
          url: 'https://catalog.example/spider-verse',
          logo: 'https://image.tmdb.org/t/p/w500/spider-verse.jpg',
          year: '2017',
          tmdbId: 324857,
          forcedType: 'movie',
        ),
      ];

      expect(
        CatalogLegacyDuplicateFilter.withoutCuratedAliases(titles),
        hasLength(2),
      );
    },
  );
}
