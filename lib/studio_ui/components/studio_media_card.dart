import 'package:flutter/material.dart';

import '../data/studio_media_item.dart';
import '../foundation/studio_tokens.dart';
import 'studio_network_image.dart';

class StudioMediaCard extends StatelessWidget {
  const StudioMediaCard({
    super.key,
    required this.item,
    required this.width,
    required this.onTap,
    this.onToggleFavorite,
    this.imageProvider,
    this.ranking,
    this.ageRating = '13+',
    this.qualityLabel,
  });

  final StudioMediaItem item;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;
  final ImageProvider<Object>? imageProvider;
  final int? ranking;
  final String ageRating;
  final String? qualityLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: _semanticLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: StudioColors.surface,
                        borderRadius: BorderRadius.circular(
                          StudioRadii.control,
                        ),
                        border: Border.all(
                          color: StudioColors.border.withValues(alpha: 0.8),
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          StudioRadii.control - 1,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            StudioNetworkImage(
                              url: item.posterUrl,
                              imageProvider: imageProvider,
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: _Badge(
                                label: item.isFeatured ? 'ORIGINAL' : ageRating,
                                accent: item.isFeatured,
                              ),
                            ),
                            if (qualityLabel != null)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: _Badge(
                                  label: qualityLabel!,
                                  accent: true,
                                  dark: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (ranking != null)
                  Positioned(
                    left: -8,
                    bottom: 4,
                    child: IgnorePointer(
                      child: Text(
                        '$ranking',
                        style: const TextStyle(
                          fontFamily: StudioTypography.family,
                          fontSize: 56,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: StudioColors.textPrimary,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (onToggleFavorite != null)
                  Positioned(
                    right: -8,
                    bottom: -8,
                    child: SizedBox.square(
                      key: const ValueKey<String>('media-card-favorite'),
                      dimension: StudioSpacing.touchTarget,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 34,
                          child: Material(
                            color: StudioColors.deepBlack.withValues(
                              alpha: 0.88,
                            ),
                            shape: const CircleBorder(
                              side: BorderSide(color: StudioColors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: onToggleFavorite,
                              child: Icon(
                                item.isFavorite
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 18,
                                color: item.isFavorite
                                    ? StudioColors.accent
                                    : StudioColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: StudioSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioTypography.label,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                <String>[
                  if (item.year?.isNotEmpty == true) item.year!,
                  if (item.genre?.isNotEmpty == true) item.genre!,
                ].join('  •  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StudioTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _semanticLabel => <String>[
    item.title,
    if (item.year?.isNotEmpty == true) item.year!,
    if (item.genre?.isNotEmpty == true) item.genre!,
  ].join(', ');
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.accent = false, this.dark = false});

  final String label;
  final bool accent;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? StudioColors.deepBlack.withValues(alpha: 0.82)
            : accent
            ? StudioColors.accent
            : StudioColors.deepBlack.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(StudioRadii.compact),
        border: dark
            ? Border.all(color: StudioColors.accent.withValues(alpha: 0.4))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: StudioTypography.family,
            fontSize: 9,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: accent ? 0.7 : 0,
            color: accent && !dark
                ? StudioColors.deepBlack
                : dark
                ? StudioColors.accent
                : StudioColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
