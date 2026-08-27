import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/hybrid_category_bar.dart';
import '../components/hybrid_overlay_menu.dart';
import '../components/hybrid_poster_card.dart';
import '../data/hybrid_catalog_controller.dart';
import '../data/hybrid_catalog_models.dart';
import '../theme/hybrid_mobile_tokens.dart';

abstract interface class HybridSearchHistoryStore {
  Future<List<String>> load();
  Future<void> save(List<String> history);
}

class SharedPreferencesHybridSearchHistoryStore
    implements HybridSearchHistoryStore {
  static const _key = 'hourtv.hybrid.search.history';

  @override
  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_key) ?? const <String>[];
  }

  @override
  Future<void> save(List<String> history) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key, history);
  }
}

class HybridSearchScreen extends StatefulWidget {
  const HybridSearchScreen({
    super.key,
    required this.catalog,
    required this.onBack,
    required this.onOpenDetails,
    this.historyStore,
  });

  final HybridCatalogController catalog;
  final VoidCallback onBack;
  final ValueChanged<HybridMediaItem> onOpenDetails;
  final HybridSearchHistoryStore? historyStore;

  @override
  State<HybridSearchScreen> createState() => _HybridSearchScreenState();
}

class _HybridSearchScreenState extends State<HybridSearchScreen> {
  static const _initialVisible = 18;
  static const _revealStep = 12;
  static const _kindLabels = <String>[
    'Todo',
    'Películas',
    'Series',
    'Anime',
    'Novelas',
  ];

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final HybridSearchHistoryStore _historyStore;
  Timer? _debounce;
  List<String> _history = const <String>[];
  String _query = '';
  String _kindLabel = _kindLabels.first;
  HybridSortOrder _sortOrder = HybridSortOrder.newest;
  int _visibleCount = _initialVisible;

  @override
  void initState() {
    super.initState();
    _historyStore =
        widget.historyStore ?? SharedPreferencesHybridSearchHistoryStore();
    _scrollController.addListener(_onScroll);
    unawaited(widget.catalog.load());
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await _historyStore.load();
    if (!mounted) return;
    setState(() => _history = history.take(10).toList(growable: false));
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _visibleCount = _initialVisible;
      });
    });
  }

  Future<void> _submitQuery([String? value]) async {
    _debounce?.cancel();
    final query = (value ?? _textController.text).trim();
    if (value != null) {
      _textController
        ..text = value
        ..selection = TextSelection.collapsed(offset: value.length);
    }
    setState(() {
      _query = query;
      _visibleCount = _initialVisible;
    });
    if (query.isEmpty) return;

    final normalized = _normalize(query);
    final next = <String>[
      ..._history.where((item) => _normalize(item) != normalized),
      query,
    ];
    if (next.length > 10) next.removeRange(0, next.length - 10);
    setState(() => _history = List<String>.unmodifiable(next));
    await _historyStore.save(_history);
  }

  Future<void> _removeHistory(String value) async {
    setState(() {
      _history = _history
          .where((item) => item != value)
          .toList(growable: false);
    });
    await _historyStore.save(_history);
  }

  Future<void> _clearHistory() async {
    setState(() => _history = const <String>[]);
    await _historyStore.save(_history);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _query.isEmpty) return;
    if (_scrollController.position.extentAfter >= 600) return;
    final resultCount = _results().length;
    if (_visibleCount >= resultCount) return;
    setState(() {
      _visibleCount = math.min(_visibleCount + _revealStep, resultCount);
    });
  }

  HybridMediaKind? get _selectedKind => switch (_kindLabel) {
    'Películas' => HybridMediaKind.movie,
    'Series' => HybridMediaKind.series,
    'Anime' => HybridMediaKind.anime,
    'Novelas' => HybridMediaKind.novela,
    _ => null,
  };

  List<HybridMediaItem> _results() {
    final results = widget.catalog.search(_query, kind: _selectedKind).toList();
    results.sort(switch (_sortOrder) {
      HybridSortOrder.newest => (a, b) => _year(b).compareTo(_year(a)),
      HybridSortOrder.oldest => (a, b) => _year(a).compareTo(_year(b)),
      HybridSortOrder.titleAscending => (a, b) => _normalize(
        a.title,
      ).compareTo(_normalize(b.title)),
    });
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = HybridMobileMetrics.fromWidth(constraints.maxWidth);
        return ListenableBuilder(
          listenable: widget.catalog,
          builder: (context, _) {
            final results = _query.isEmpty
                ? const <HybridMediaItem>[]
                : _results();
            final visible = results.take(_visibleCount).toList(growable: false);
            return CustomScrollView(
              key: const PageStorageKey<String>('hybrid-search-scroll'),
              controller: _scrollController,
              slivers: <Widget>[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchHeaderDelegate(
                    controller: _textController,
                    onBack: widget.onBack,
                    onChanged: _onQueryChanged,
                    onSubmitted: _submitQuery,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SearchControls(
                    kindLabel: _kindLabel,
                    sortOrder: _sortOrder,
                    onKindSelected: (value) {
                      setState(() {
                        _kindLabel = value;
                        _visibleCount = _initialVisible;
                      });
                    },
                    onSortSelected: (value) {
                      setState(() {
                        _sortOrder = value;
                        _visibleCount = _initialVisible;
                      });
                    },
                  ),
                ),
                if (_query.isEmpty)
                  SliverToBoxAdapter(
                    child: _SearchSuggestions(
                      history: _history,
                      popular: widget.catalog.all
                          .take(10)
                          .toList(growable: false),
                      onSearch: _submitQuery,
                      onRemoveHistory: _removeHistory,
                      onClearHistory: _clearHistory,
                    ),
                  )
                else ...<Widget>[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      metrics.horizontalPadding,
                      HybridMobileTokens.lg,
                      metrics.horizontalPadding,
                      HybridMobileTokens.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '${results.length} ${results.length == 1 ? 'resultado' : 'resultados'}',
                        style: HybridMobileTypography.title,
                      ),
                    ),
                  ),
                  if (results.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(HybridMobileTokens.xxl),
                          child: Text(
                            'No encontramos títulos para esta búsqueda.',
                            textAlign: TextAlign.center,
                            style: HybridMobileTypography.body,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.horizontalPadding,
                      ),
                      sliver: SliverGrid(
                        key: const ValueKey<String>(
                          'hybrid-search-results-grid',
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: metrics.posterColumns,
                          crossAxisSpacing: metrics.gutter,
                          mainAxisSpacing: HybridMobileTokens.lg,
                          childAspectRatio:
                              metrics.posterWidth /
                              (metrics.posterWidth /
                                      HybridMobileTokens.posterAspectRatio +
                                  54),
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = visible[index];
                          return HybridPosterCard(
                            item: item,
                            isInMyList: widget.catalog.isInMyList(item.id),
                            onTap: () => widget.onOpenDetails(item),
                          );
                        }, childCount: visible.length),
                      ),
                    ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        HybridMobileTokens.bottomNavigationHeight +
                        MediaQuery.paddingOf(context).bottom +
                        HybridMobileTokens.md,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static int _year(HybridMediaItem item) => int.tryParse(item.year ?? '') ?? 0;

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâã]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöôõ]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SearchHeaderDelegate({
    required this.controller,
    required this.onBack,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 68;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: HybridMobileTokens.header,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HybridMobileTokens.md,
          vertical: 10,
        ),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: HybridMobileTokens.minTouchTarget,
              child: IconButton(
                onPressed: onBack,
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(width: HybridMobileTokens.sm),
            Expanded(
              child: TextField(
                key: const ValueKey<String>('hybrid-search-field'),
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                style: HybridMobileTypography.body.copyWith(
                  color: HybridMobileTokens.textPrimary,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  hintText: 'Buscar película, serie o género...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: HybridMobileTokens.sm),
            Semantics(
              label: 'Buscar',
              button: true,
              child: SizedBox.square(
                dimension: HybridMobileTokens.minTouchTarget,
                child: IconButton.filled(
                  onPressed: () => onSubmitted(controller.text),
                  style: IconButton.styleFrom(
                    backgroundColor: HybridMobileTokens.accent,
                    foregroundColor: HybridMobileTokens.textPrimary,
                  ),
                  icon: const Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.onBack != onBack ||
      oldDelegate.onChanged != onChanged ||
      oldDelegate.onSubmitted != onSubmitted;
}

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.kindLabel,
    required this.sortOrder,
    required this.onKindSelected,
    required this.onSortSelected,
  });

  final String kindLabel;
  final HybridSortOrder sortOrder;
  final ValueChanged<String> onKindSelected;
  final ValueChanged<HybridSortOrder> onSortSelected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: HybridMobileTokens.header,
    child: Column(
      children: <Widget>[
        HybridCategoryBar(
          categories: _HybridSearchScreenState._kindLabels,
          selected: kindLabel,
          onSelected: onKindSelected,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HybridMobileTokens.lg,
            0,
            HybridMobileTokens.lg,
            HybridMobileTokens.sm,
          ),
          child: Row(
            children: <Widget>[
              const Text('Ordenar', style: HybridMobileTypography.caption),
              const Spacer(),
              HybridOverlayMenu<HybridSortOrder>(
                value: sortOrder,
                values: HybridSortOrder.values,
                labelBuilder: _sortLabel,
                onSelected: onSortSelected,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _sortLabel(HybridSortOrder value) => switch (value) {
    HybridSortOrder.newest => 'Más recientes',
    HybridSortOrder.oldest => 'Más antiguos',
    HybridSortOrder.titleAscending => 'Orden A–Z',
  };
}

class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({
    required this.history,
    required this.popular,
    required this.onSearch,
    required this.onRemoveHistory,
    required this.onClearHistory,
  });

  final List<String> history;
  final List<HybridMediaItem> popular;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onRemoveHistory;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(HybridMobileTokens.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Historial de búsquedas',
                style: HybridMobileTypography.title,
              ),
            ),
            if (history.isNotEmpty)
              IconButton(
                onPressed: onClearHistory,
                tooltip: 'Limpiar historial',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: HybridMobileTokens.md),
            child: Text(
              'Todavía no hay búsquedas guardadas.',
              style: HybridMobileTypography.body,
            ),
          )
        else
          for (final item in history.reversed)
            _HistoryRow(
              value: item,
              onTap: () => onSearch(item),
              onRemove: () => onRemoveHistory(item),
            ),
        const SizedBox(height: HybridMobileTokens.xxl),
        const Text('Búsquedas populares', style: HybridMobileTypography.title),
        const SizedBox(height: HybridMobileTokens.sm),
        for (var index = 0; index < popular.length; index++)
          _PopularRow(
            index: index + 1,
            item: popular[index],
            onTap: () => onSearch(popular[index].title),
          ),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.value,
    required this.onTap,
    required this.onRemove,
  });

  final String value;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(
      minHeight: HybridMobileTokens.minTouchTarget,
    ),
    child: Row(
      children: <Widget>[
        const Icon(
          Icons.history_rounded,
          size: 18,
          color: HybridMobileTokens.textSecondary,
        ),
        const SizedBox(width: HybridMobileTokens.md),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(value, style: HybridMobileTypography.body),
            ),
          ),
        ),
        Semantics(
          label: 'Eliminar $value',
          button: true,
          child: SizedBox.square(
            dimension: HybridMobileTokens.minTouchTarget,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PopularRow extends StatelessWidget {
  const _PopularRow({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final HybridMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HybridMobileTokens.minTouchTarget,
      ),
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: index == 1
                    ? HybridMobileTokens.accent
                    : HybridMobileTokens.surfaceElevated,
                borderRadius: BorderRadius.circular(
                  HybridMobileTokens.radiusSmall,
                ),
              ),
              child: Center(
                child: Text('$index', style: HybridMobileTypography.label),
              ),
            ),
          ),
          const SizedBox(width: HybridMobileTokens.md),
          Expanded(child: Text(item.title, style: HybridMobileTypography.body)),
        ],
      ),
    ),
  );
}
