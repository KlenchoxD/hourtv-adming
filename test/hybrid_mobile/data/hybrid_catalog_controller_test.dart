import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_controller.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_models.dart';
import 'package:streamtv/studio_ui/data/studio_media_item.dart';

void main() {
  group('HybridCatalogController', () {
    late _FakeCatalogSource source;
    late HybridCatalogController controller;

    setUp(() {
      source = _FakeCatalogSource(_fixtureItems());
      controller = HybridCatalogController(source: source);
    });

    tearDown(() => controller.dispose());

    test('loads once and projects movies, series, anime and novelas', () async {
      await controller.load();

      expect(source.loadCount, 1);
      expect(controller.all, hasLength(4));
      expect(
        controller.all.map((item) => item.kind),
        containsAll(HybridMediaKind.values),
      );
      expect(
        controller.homeSections.map((section) => section.kind),
        containsAll(HybridMediaKind.values),
      );
      expect(controller.homeSections.every((section) => section.items.isNotEmpty), isTrue);
    });

    test('search is case and accent insensitive', () async {
      await controller.load();

      expect(controller.search('alma cristal').single.id, 'anime-1');
      expect(controller.search('FRONTERA').single.id, 'series-1');
      expect(controller.search('   '), controller.all);
    });

    test('filters by kind and sorts by year or title', () async {
      await controller.load();

      expect(
        controller.filter(kind: HybridMediaKind.novela).single.id,
        'novela-1',
      );
      expect(
        controller
            .filter(order: HybridSortOrder.oldest)
            .map((item) => item.year),
        orderedEquals(<String?>['2022', '2023', '2024', '2026']),
      );
      expect(
        controller
            .filter(order: HybridSortOrder.titleAscending)
            .first
            .title,
        'Álma de cristal',
      );
    });

    test('toggles My List through the existing catalog source', () async {
      await controller.load();
      final item = controller.all.first;

      expect(controller.isInMyList(item.id), isFalse);
      await controller.toggleMyList(item.id);
      expect(source.toggledIds, <String>[item.id]);
      expect(controller.isInMyList(item.id), isTrue);

      await controller.toggleMyList(item.id);
      expect(controller.isInMyList(item.id), isFalse);
    });

    test('reacts to source changes without reloading it', () async {
      await controller.load();
      var notifications = 0;
      controller.addListener(() => notifications++);

      source.items = <StudioMediaItem>[...source.items, _movie('new', 'Nueva', '2027')];
      source.notifyListeners();

      expect(controller.all, hasLength(5));
      expect(source.loadCount, 1);
      expect(notifications, 1);
    });
  });
}

List<StudioMediaItem> _fixtureItems() => <StudioMediaItem>[
  _movie('movie-1', 'El último amanecer', '2026'),
  StudioMediaItem(
    id: 'series-1',
    title: 'Frontera Roja',
    kind: StudioMediaKind.series,
    source: const _SourceToken('series-1'),
    genre: 'Drama',
    year: '2024',
  ),
  StudioMediaItem(
    id: 'anime-1',
    title: 'Álma de cristal',
    kind: StudioMediaKind.series,
    source: const _SourceToken('anime-1'),
    genre: 'Animé',
    year: '2023',
  ),
  StudioMediaItem(
    id: 'novela-1',
    title: 'Pasiones cruzadas',
    kind: StudioMediaKind.series,
    source: const _SourceToken('novela-1'),
    categories: const <String>['Telenovelas'],
    year: '2022',
  ),
];

StudioMediaItem _movie(String id, String title, String year) => StudioMediaItem(
  id: id,
  title: title,
  kind: StudioMediaKind.movie,
  source: _SourceToken(id),
  genre: 'Drama',
  year: year,
);

class _SourceToken {
  const _SourceToken(this.id);
  final String id;
}

class _FakeCatalogSource extends ChangeNotifier implements HybridCatalogSource {
  _FakeCatalogSource(this.items);

  List<StudioMediaItem> items;
  int loadCount = 0;
  final List<String> toggledIds = <String>[];

  @override
  Future<void> ensureLoaded() async => loadCount++;

  @override
  List<StudioMediaItem> snapshot() => List<StudioMediaItem>.of(items);

  @override
  Future<bool> toggleMyList(StudioMediaItem item) async {
    toggledIds.add(item.id);
    return toggledIds.where((id) => id == item.id).length.isOdd;
  }
}
