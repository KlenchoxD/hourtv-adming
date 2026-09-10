import 'package:flutter/foundation.dart';
import '../../database/catalog_database.dart';
import '../../database/daos/catalog_dao.dart';

/// Origen de datos reactivo y paginado determinista por cursor tupla (createdAt, id)
/// conectado directamente a la base de datos local SQLite (Drift).
class CatalogPageSource extends ChangeNotifier {
  final CatalogDao dao;
  final int pageSize;
  final String? mediaType;
  final String? genreSlug;

  List<LocalTitle> _items = [];
  List<LocalTitle> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  DateTime? _cursorCreatedAt;
  String? _cursorId;

  CatalogPageSource({
    required this.dao,
    this.pageSize = 20,
    this.mediaType,
    this.genreSlug,
  });

  /// Reinicia el cursor y carga la primera página.
  Future<void> loadInitialPage() async {
    _cursorCreatedAt = null;
    _cursorId = null;
    _items = [];
    _hasMore = true;
    await loadNextPage();
  }

  /// Carga la siguiente página determinista basada en el cursor actual.
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();

    try {
      final newItems = await dao.getPage(
        limit: pageSize,
        cursorCreatedAt: _cursorCreatedAt,
        cursorId: _cursorId,
        mediaType: mediaType,
        genreSlug: genreSlug,
      );

      if (newItems.isNotEmpty) {
        _items.addAll(newItems);
        final last = newItems.last;
        _cursorCreatedAt = last.createdAt;
        _cursorId = last.id;
      }

      _hasMore = newItems.length >= pageSize;
    } catch (_) {
      // Manejo seguro ante excepciones locales
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Realiza una búsqueda FTS5 sanitizada y parametrizada.
  Future<void> search(String query) async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await dao.searchTitlesFts(
        rawQuery: query,
        mediaType: mediaType,
        genreSlug: genreSlug,
        limit: pageSize,
      );
      _hasMore = false;
    } catch (_) {
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
