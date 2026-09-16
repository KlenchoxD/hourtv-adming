import 'package:flutter/foundation.dart';
import '../../database/catalog_database.dart';
import '../../database/daos/catalog_dao.dart';
import 'catalog_dtos.dart';
import 'catalog_repository.dart';

/// Origen de datos reactivo y paginado determinista por cursor tupla (createdAt, id)
/// conectado directamente a la base de datos local SQLite (Drift).
/// Incluye protecciones contra carreras en búsquedas/paginación, de-duplicación
/// estricta por ID y manejo seguro de dispose.
class CatalogPageSource extends ChangeNotifier {
  final CatalogDao dao;
  final CatalogRepository? repository;
  final int pageSize;
  String? mediaType;
  String? genreSlug;
  CatalogSortOrder sort;

  CatalogRepository? _attachedRepo;
  bool _needsReloadAfterLoading = false;
  bool _disposed = false;
  bool get isDisposed => _disposed;

  int _searchSequence = 0;
  final Set<String> _seenIds = <String>{};

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
    _disposed = true;
    _attachedRepo?.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _onRepositoryChanged() {
    if (_disposed || _lastSearchQuery != null) return;
    if (_isLoading) {
      _needsReloadAfterLoading = true;
      return;
    }
    refresh();
  }

  /// Reinicia el cursor y carga la primera página.
  Future<void> loadInitialPage() async {
    if (_disposed) return;
    _lastSearchQuery = null;
    final currentSeq = ++_searchSequence;
    _cursorCreatedAt = null;
    _cursorId = null;
    _items = [];
    _seenIds.clear();
    _hasMore = true;
    _error = null;
    await _loadPageInternal(currentSeq, isInitial: true);
  }

  /// Carga la siguiente página determinista basada en el cursor actual.
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore || _disposed) return;
    final currentSeq = _searchSequence;
    await _loadPageInternal(currentSeq, isInitial: false);
  }

  Future<void> _loadPageInternal(int seq, {required bool isInitial}) async {
    if (_disposed || seq != _searchSequence) return;
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final newItems = await dao.getPage(
        limit: pageSize,
        cursorCreatedAt: _cursorCreatedAt,
        cursorId: _cursorId,
        mediaType: mediaType,
        genreSlug: genreSlug,
        sort: sort,
      );

      if (_disposed || seq != _searchSequence) return;

      if (isInitial) {
        _items = [];
        _seenIds.clear();
      }

      for (final item in newItems) {
        if (_seenIds.add(item.id)) {
          _items.add(item);
        }
      }

      if (newItems.isNotEmpty) {
        final last = newItems.last;
        _cursorCreatedAt = last.createdAt;
        _cursorId = last.id;
      }

      _hasMore = newItems.length >= pageSize;
    } catch (e) {
      if (_disposed || seq != _searchSequence) return;
      _error = e;
    } finally {
      if (!_disposed && seq == _searchSequence) {
        _isLoading = false;
        _safeNotifyListeners();
        if (_needsReloadAfterLoading) {
          _needsReloadAfterLoading = false;
          refresh();
        }
      }
    }
  }

  /// Recarga el catálogo reactivamente desde el inicio preservando elementos
  /// existentes mientras carga para evitar parpadeos en pantalla.
  Future<void> refresh() async {
    if (_disposed) return;
    if (_isLoading) {
      _needsReloadAfterLoading = true;
      return;
    }
    final currentSeq = ++_searchSequence;
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final newItems = await dao.getPage(
        limit: pageSize,
        cursorCreatedAt: null,
        cursorId: null,
        mediaType: mediaType,
        genreSlug: genreSlug,
        sort: sort,
      );

      if (_disposed || currentSeq != _searchSequence) return;

      _items = [];
      _seenIds.clear();
      for (final item in newItems) {
        if (_seenIds.add(item.id)) {
          _items.add(item);
        }
      }

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
      if (_disposed || currentSeq != _searchSequence) return;
      _error = e;
    } finally {
      if (!_disposed && currentSeq == _searchSequence) {
        _isLoading = false;
        _safeNotifyListeners();
        if (_needsReloadAfterLoading) {
          _needsReloadAfterLoading = false;
          refresh();
        }
      }
    }
  }

  /// Reintenta la última operación fallida preservando el estado previo.
  Future<void> retry() async {
    if (_isLoading || _disposed) return;
    if (_lastSearchQuery != null) {
      await search(_lastSearchQuery!);
    } else {
      await loadNextPage();
    }
  }

  /// Realiza una búsqueda FTS5 sanitizada y parametrizada con control estricto de carreras.
  Future<void> search(String query) async {
    if (_disposed) return;
    _lastSearchQuery = query;
    final currentSeq = ++_searchSequence;
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final results = await dao.searchTitlesFts(
        rawQuery: query,
        mediaType: mediaType,
        genreSlug: genreSlug,
        sort: sort,
        limit: pageSize,
      );

      if (_disposed || currentSeq != _searchSequence) return;

      _items = results;
      _seenIds.clear();
      for (final item in results) {
        _seenIds.add(item.id);
      }
      _hasMore = false;
    } catch (e) {
      if (_disposed || currentSeq != _searchSequence) return;
      _error = e;
    } finally {
      if (!_disposed && currentSeq == _searchSequence) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }
}
