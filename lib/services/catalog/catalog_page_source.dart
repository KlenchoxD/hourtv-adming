import 'package:flutter/foundation.dart';
import '../../database/catalog_database.dart';
import '../../database/daos/catalog_dao.dart';
import 'catalog_dtos.dart';
import 'supabase_catalog_gateway.dart';

/// Origen de datos reactivo y paginado determinista por cursor tupla (createdAt, id)
/// conectado directamente a la base de datos local SQLite (Drift).
class CatalogPageSource extends ChangeNotifier {
  final CatalogDao dao;
  final int pageSize;
  final String? mediaType;
  final String? genreSlug;
  final CatalogSortOrder sort;

  List<LocalTitle> _items = [];
  List<LocalTitle> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Object? _error;
  Object? get error => _error;
  bool get hasError => _error != null;

  bool get isEmpty => !_isLoading && _error == null && _items.isEmpty;

  DateTime? _cursorCreatedAt;
  String? _cursorId;
  String? _lastSearchQuery;

  CatalogPageSource({
    required this.dao,
    this.pageSize = 20,
    this.mediaType,
    this.genreSlug,
    this.sort = CatalogSortOrder.recent,
  });

  /// Reinicia el cursor y carga la primera página.
  Future<void> loadInitialPage() async {
    _lastSearchQuery = null;
    _cursorCreatedAt = null;
    _cursorId = null;
    _items = [];
    _hasMore = true;
    _error = null;
    await loadNextPage();
  }

  /// Carga la siguiente página determinista basada en el cursor actual.
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newItems = await dao.getPage(
        limit: pageSize,
        cursorCreatedAt: _cursorCreatedAt,
        cursorId: _cursorId,
        mediaType: mediaType,
        genreSlug: genreSlug,
        sort: sort,
      );

      if (newItems.isNotEmpty) {
        _items.addAll(newItems);
        final last = newItems.last;
        _cursorCreatedAt = last.createdAt;
        _cursorId = last.id;
      }

      _hasMore = newItems.length >= pageSize;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reintenta la última operación fallida preservando el estado previo.
  Future<void> retry() async {
    if (_isLoading) return;
    if (_lastSearchQuery != null) {
      await search(_lastSearchQuery!);
    } else {
      await loadNextPage();
    }
  }

  /// Realiza una búsqueda FTS5 sanitizada y parametrizada.
  Future<void> search(String query) async {
    _lastSearchQuery = query;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await dao.searchTitlesFts(
        rawQuery: query,
        mediaType: mediaType,
        genreSlug: genreSlug,
        sort: sort,
        limit: pageSize,
      );
      _hasMore = false;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
