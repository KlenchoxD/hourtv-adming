import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../components/hybrid_brand_header.dart';
import '../components/hybrid_category_bar.dart';
import '../components/hybrid_poster_card.dart';
import '../components/hybrid_section.dart';
import '../data/hybrid_catalog_controller.dart';
import '../data/hybrid_catalog_models.dart';
import '../theme/hybrid_mobile_tokens.dart';

class HybridHomeScreen extends StatefulWidget {
  const HybridHomeScreen({
    super.key,
    required this.catalog,
    required this.onFilter,
    required this.onSearch,
    required this.onOpenDetails,
  });

  final HybridCatalogController catalog;
  final VoidCallback onFilter;
  final VoidCallback onSearch;
  final ValueChanged<HybridMediaItem> onOpenDetails;

  @override
  State<HybridHomeScreen> createState() => _HybridHomeScreenState();
}

class _HybridHomeScreenState extends State<HybridHomeScreen> {
  static const categories = <String>[
    'Recomendado',
    'Infantil',
    'Terror',
    'Acción',
    'Comedia',
    'Romance',
    'Aventura',
  ];

  String _selectedCategory = categories.first;

  @override
  void initState() {
    super.initState();
    unawaited(widget.catalog.load());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = HybridMobileMetrics.fromWidth(constraints.maxWidth);
        return ListenableBuilder(
          listenable: widget.catalog,
          builder: (context, _) {
            final sections = _sectionsForSelection();
            final bannerItem = _bannerItem(sections);
            return CustomScrollView(
              key: const PageStorageKey<String>('hybrid-home-scroll'),
              slivers: <Widget>[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _HomeHeaderDelegate(
                    selectedCategory: _selectedCategory,
                    onCategorySelected: (value) {
                      if (value == _selectedCategory) return;
                      setState(() => _selectedCategory = value);
                    },
                    onFilter: widget.onFilter,
                    onSearch: widget.onSearch,
                  ),
                ),
                if (bannerItem != null)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      metrics.horizontalPadding,
                      HybridMobileTokens.sm,
                      metrics.horizontalPadding,
                      HybridMobileTokens.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _HomeBanner(
                        item: bannerItem,
                        onTap: () => widget.onOpenDetails(bannerItem),
                      ),
                    ),
                  ),
                if (sections.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No hay títulos en esta categoría.',
                        style: HybridMobileTypography.body,
                      ),
                    ),
                  )
                else
                  for (final section in sections)
                    SliverToBoxAdapter(
                      child: _HomeSection(
                        section: section,
                        metrics: metrics,
                        catalog: widget.catalog,
                        onOpenDetails: widget.onOpenDetails,
                      ),
                    ),
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

  List<HybridMediaSection> _sectionsForSelection() {
    if (_selectedCategory == categories.first) {
      return widget.catalog.homeSections;
    }
    final items = widget.catalog.filter(genre: _selectedCategory);
    return _group(items);
  }

  List<HybridMediaSection> _group(List<HybridMediaItem> items) {
    const titles = <HybridMediaKind, String>{
      HybridMediaKind.movie: 'Películas más populares',
      HybridMediaKind.series: 'Series para maratonear',
      HybridMediaKind.anime: 'Anime',
      HybridMediaKind.novela: 'Novelas',
    };
    return <HybridMediaSection>[
      for (final kind in HybridMediaKind.values)
        if (items.any((item) => item.kind == kind))
          HybridMediaSection(
            id: 'home-${kind.name}-$_selectedCategory',
            title: titles[kind]!,
            kind: kind,
            items: List<HybridMediaItem>.unmodifiable(
              items.where((item) => item.kind == kind),
            ),
          ),
    ];
  }

  HybridMediaItem? _bannerItem(List<HybridMediaSection> sections) {
    final items = sections.expand((section) => section.items).toList();
    if (items.isEmpty) return null;
    return items.cast<HybridMediaItem?>().firstWhere(
      (item) => item?.isFeatured == true,
      orElse: () => items.first,
    );
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HomeHeaderDelegate({
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onFilter,
    required this.onSearch,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onFilter;
  final VoidCallback onSearch;

  static const extent =
      HybridMobileTokens.headerHeight + HybridMobileTokens.minTouchTarget;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HybridMobileTokens.header,
        border: Border(
          bottom: BorderSide(
            color: HybridMobileTokens.border.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Column(
        children: <Widget>[
          HybridBrandHeader(onFilter: onFilter, onSearch: onSearch),
          HybridCategoryBar(
            categories: _HybridHomeScreenState.categories,
            selected: selectedCategory,
            onSelected: onCategorySelected,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) =>
      oldDelegate.selectedCategory != selectedCategory ||
      oldDelegate.onCategorySelected != onCategorySelected ||
      oldDelegate.onFilter != onFilter ||
      oldDelegate.onSearch != onSearch;
}

class _HomeBanner extends StatelessWidget {
  const _HomeBanner({required this.item, required this.onTap});

  final HybridMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Destacado: ${item.title}',
      button: true,
      child: InkWell(
        key: const ValueKey<String>('hybrid-home-banner'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(HybridMobileTokens.radiusSmall),
        splashColor: Colors.transparent,
        highlightColor: HybridMobileTokens.accentSoft,
        child: AspectRatio(
          aspectRatio: 1.65,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(HybridMobileTokens.radiusSmall),
            child: _BannerArtwork(url: item.backdropUrl ?? item.posterUrl),
          ),
        ),
      ),
    );
  }
}

class _BannerArtwork extends StatelessWidget {
  const _BannerArtwork({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final source = url?.trim() ?? '';
    if (source.isEmpty) return const _BannerFallback();
    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => const _BannerFallback(),
      errorWidget: (_, _, _) => const _BannerFallback(),
    );
  }
}

class _BannerFallback extends StatelessWidget {
  const _BannerFallback();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF667EEA), Color(0xFF764BA2)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.local_movies_outlined,
        size: 42,
        color: HybridMobileTokens.textPrimary,
      ),
    ),
  );
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.section,
    required this.metrics,
    required this.catalog,
    required this.onOpenDetails,
  });

  final HybridMediaSection section;
  final HybridMobileMetrics metrics;
  final HybridCatalogController catalog;
  final ValueChanged<HybridMediaItem> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final posterHeight =
        metrics.posterWidth / HybridMobileTokens.posterAspectRatio + 54;
    return Padding(
      padding: const EdgeInsets.only(bottom: HybridMobileTokens.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.horizontalPadding,
            ),
            child: HybridSectionHeader(title: section.title),
          ),
          const SizedBox(height: HybridMobileTokens.sm),
          SizedBox(
            height: posterHeight,
            child: ListView.separated(
              key: PageStorageKey<String>('hybrid-home-${section.id}'),
              padding: EdgeInsets.symmetric(
                horizontal: metrics.horizontalPadding,
              ),
              scrollDirection: Axis.horizontal,
              scrollCacheExtent: ScrollCacheExtent.pixels(
                metrics.posterWidth * 4,
              ),
              itemCount: section.items.length,
              separatorBuilder: (_, _) => SizedBox(width: metrics.gutter),
              itemBuilder: (context, index) {
                final item = section.items[index];
                return SizedBox(
                  width: metrics.posterWidth,
                  child: HybridPosterCard(
                    item: item,
                    isInMyList: catalog.isInMyList(item.id),
                    onTap: () => onOpenDetails(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
