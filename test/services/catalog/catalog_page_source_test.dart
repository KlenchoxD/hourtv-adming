import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/database/catalog_database.dart';
import 'package:streamtv/database/daos/catalog_dao.dart';
import 'package:streamtv/services/catalog/catalog_dtos.dart';
import 'package:streamtv/services/catalog/catalog_page_source.dart';

class TestCatalogDao extends CatalogDao {
  TestCatalogDao(super.db);

  bool shouldFailNextPage = false;
  bool shouldFailSearch = false;
  int getPageCalls = 0;
  List<LocalTitle> customPageResult = [];

  @override
  Future<List<LocalTitle>> getPage({
    int limit = 20,
    DateTime? cursorCreatedAt,
    String? cursorId,
    String? mediaType,
    int? year,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
  }) async {
    getPageCalls++;
    if (shouldFailNextPage) {
      throw Exception('SQLite disk I/O failure or network timeout');
    }
    if (customPageResult.isNotEmpty) {
      return customPageResult;
    }
    return super.getPage(
      limit: limit,
      cursorCreatedAt: cursorCreatedAt,
      cursorId: cursorId,
      mediaType: mediaType,
      year: year,
      genreSlug: genreSlug,
      sort: sort,
    );
  }

  @override
  Future<List<LocalTitle>> searchTitlesFts({
    required String rawQuery,
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder sort = CatalogSortOrder.recent,
    int limit = 20,
  }) async {
    if (shouldFailSearch) {
      throw Exception('FTS syntax error or corrupted table');
    }
    return super.searchTitlesFts(
      rawQuery: rawQuery,
      mediaType: mediaType,
      genreSlug: genreSlug,
      sort: sort,
      limit: limit,
    );
  }
}

void main() {
  late CatalogDatabase db;
  late TestCatalogDao dao;
  late CatalogPageSource pageSource;

  setUp(() {
    db = CatalogDatabase.inMemory();
    dao = TestCatalogDao(db);
    pageSource = CatalogPageSource(dao: dao, pageSize: 2);
  });

  tearDown(() async {
    await db.close();
  });

  LocalTitle createTitle(String id, String title, DateTime dt) {
    return LocalTitle(
      id: id,
      title: title,
      normalizedTitle: title.toLowerCase(),
      mediaType: 'movie',
      rating: 8.0,
      isFeatured: false,
      createdAt: dt,
      updatedAt: dt,
      isDeleted: false,
    );
  }

  test('1. Fallo en página 1: expone error, hasError=true, isEmpty=false y retry() recupera datos', () async {
    dao.shouldFailNextPage = true;

    await pageSource.loadInitialPage();

    expect(pageSource.hasError, isTrue);
    expect(pageSource.error, isNotNull);
    expect(pageSource.isEmpty, isFalse, reason: 'Error no debe enmascararse como catálogo vacío');
    expect(pageSource.items, isEmpty);
    expect(pageSource.hasMore, isTrue, reason: 'hasMore debe seguir true para permitir reintento');

    // Recuperación con retry()
    dao.shouldFailNextPage = false;
    final now = DateTime.now();
    dao.customPageResult = [
      createTitle('t1', 'Title 1', now),
      createTitle('t2', 'Title 2', now.subtract(const Duration(seconds: 1))),
    ];

    await pageSource.retry();

    expect(pageSource.hasError, isFalse);
    expect(pageSource.error, isNull);
    expect(pageSource.items.length, equals(2));
    expect(pageSource.items.map((e) => e.id).toList(), equals(['t1', 't2']));
    expect(pageSource.isEmpty, isFalse);
  });

  test('2. Fallo en página 2: conserva items de página 1 y retry() no duplica items', () async {
    final now = DateTime.now();
    dao.customPageResult = [
      createTitle('t1', 'Title 1', now),
      createTitle('t2', 'Title 2', now.subtract(const Duration(seconds: 1))),
    ];

    await pageSource.loadInitialPage();
    expect(pageSource.items.length, equals(2));
    expect(pageSource.hasError, isFalse);

    // Página 2 falla
    dao.shouldFailNextPage = true;
    dao.customPageResult = [];

    await pageSource.loadNextPage();

    expect(pageSource.hasError, isTrue);
    expect(pageSource.error, isNotNull);
    // Conserva página 1
    expect(pageSource.items.length, equals(2));
    expect(pageSource.items.first.id, equals('t1'));

    // Reintento exitoso
    dao.shouldFailNextPage = false;
    dao.customPageResult = [
      createTitle('t3', 'Title 3', now.subtract(const Duration(seconds: 2))),
    ];

    await pageSource.retry();

    expect(pageSource.hasError, isFalse);
    expect(pageSource.error, isNull);
    expect(pageSource.items.length, equals(3));
    expect(pageSource.items.map((e) => e.id).toList(), equals(['t1', 't2', 't3']));
    expect(pageSource.hasMore, isFalse, reason: 'Página 2 devolvió menos de pageSize=2');
  });

  test('3. Distingue correctamente catálogo vacío real de un estado con error', () async {
    dao.customPageResult = [];
    await pageSource.loadInitialPage();

    expect(pageSource.hasError, isFalse);
    expect(pageSource.error, isNull);
    expect(pageSource.items, isEmpty);
    expect(pageSource.isEmpty, isTrue, reason: 'Sin error y sin items = isEmpty verdadero');
  });

  test('4. Búsqueda FTS5 maneja error y expone hasError y error', () async {
    dao.shouldFailSearch = true;

    await pageSource.search('Matrix');

    expect(pageSource.hasError, isTrue);
    expect(pageSource.error, isNotNull);
    expect(pageSource.isEmpty, isFalse);
  });
}
