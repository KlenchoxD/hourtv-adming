import 'package:flutter/foundation.dart';
import '../../database/catalog_database.dart';
import '../../database/daos/catalog_dao.dart';
import 'catalog_dtos.dart';
import 'catalog_repository.dart';

/// Origen de datos reactivo y paginado determinista por cursor tupla (createdAt, id)
/// conectado directamente a la base de datos local SQLite (Drift).
class CatalogPageSource extends ChangeNotifier {
  final CatalogDao dao;
  final CatalogRepository? repository;
  final int pageSize;
  String? mediaType;
  String? genreSlug;
  CatalogSortOrder sort;

  CatalogRepository? _attachedRepo;
  bool _needsReloadAfterLoading = false;

  void updateFilters({
    String? mediaType,
    String? genreSlug,
    CatalogSortOrder? sort,
  }) {
    this.mediaType = mediaType;
    this.genreSlug = genreSlug;
    if (sort != null) {
      this.sort = sort;
    }
  }

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
    this.repository,
    this.pageSize = 20,
    this.mediaType,
    this.genreSlug,
    this.sort = CatalogSortOrder.recent,
  }) {
    _attachedRepo = repository ?? (CatalogRepository.hasInstance ? CatalogRepository.instance : null);
    _attachedRepo?.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    _attachedRepo?.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (_lastSearchQuery != null) return;
    if (_isLoading) {
      _needsReloadAfterLoading = true;
      return;
    }
    refresh();
  }

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
      if (_needsReloadAfterLoading) {
        _needsReloadAfterLoading = false;
        refresh();
      }
    }
  }

  /// Recarga el catálogo reactivamente desde el inicio preservando elementos
  /// existentes mientras carga para evitar parpadeos en pantalla.
  Future<void> refresh() async {
    if (_isLoading) {
      _needsReloadAfterLoading = true;
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newItems = await dao.getPage(
        limit: pageSize,
        cursorCreatedAt: null,
        cursorId: null,
        mediaType: mediaType,
        genreSlug: genreSlug,
        sort: sort,
      );

      _items = List.of(newItems);
      if (newItems.isNotEmpty) {
        final last = newItems.last;
        _cursorCreatedAt = last.createdAt;
        _cursorId = last.id;
      } else {
        _cursorCreatedAt = null;
        _cursorId = null;
      }

      _hasMore = newItems.length >= pageSize;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
      if (_needsReloadAfterLoading) {
        _needsReloadAfterLoading = false;
        refresh();
      }
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
