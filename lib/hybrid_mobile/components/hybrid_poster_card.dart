import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/hybrid_catalog_models.dart';
import '../theme/hybrid_mobile_tokens.dart';

class HybridPosterCard extends StatelessWidget {
  const HybridPosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onMyList,
    this.showMetadata = true,
    this.isInMyList = false,
  });

  final HybridMediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onMyList;
  final bool showMetadata;
  final bool isInMyList;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.title,
      button: true,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HybridMobileTokens.radiusCard),
          splashColor: Colors.transparent,
          highlightColor: HybridMobileTokens.accentSoft,
          focusColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                key: const ValueKey<String>('hybrid-poster-artwork'),
                aspectRatio: HybridMobileTokens.posterAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    HybridMobileTokens.radiusCard,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _Artwork(url: item.posterUrl),
                      if (onMyList != null)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Semantics(
                            label: isInMyList
                                ? 'Quitar de Mi Lista'
                                : 'Añadir a Mi Lista',
                            button: true,
                            child: SizedBox.square(
                              dimension: HybridMobileTokens.minTouchTarget,
                              child: IconButton.filled(
                                onPressed: onMyList,
                                style: IconButton.styleFrom(
                                  backgroundColor: HybridMobileTokens.header
                                      .withValues(alpha: 0.88),
                                  foregroundColor: isInMyList
                                      ? HybridMobileTokens.accent
                                      : HybridMobileTokens.textPrimary,
                                ),
                                icon: Icon(
                                  isInMyList
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HybridMobileTypography.label,
                ),
              ),
              if (showMetadata)
                SizedBox(
                  height: 16,
                  child: Text(
                    <String>[
                      if (item.year?.trim().isNotEmpty == true) item.year!,
                      if (item.genre?.trim().isNotEmpty == true) item.genre!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HybridMobileTypography.caption,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final source = url?.trim() ?? '';
    if (source.isEmpty) return _fallback();
    return CachedNetworkImage(
      imageUrl: source,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => const ColoredBox(
        color: HybridMobileTokens.surfaceElevated,
      ),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => const ColoredBox(
    color: HybridMobileTokens.surfaceElevated,
    child: Center(
      child: Icon(
        Icons.movie_outlined,
        color: HybridMobileTokens.textMuted,
        size: 28,
      ),
    ),
  );
}
