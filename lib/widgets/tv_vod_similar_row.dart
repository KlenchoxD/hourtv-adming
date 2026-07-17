import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tv_focusable.dart';

class TvVodSimilarRow<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T item) titleOf;
  final String? Function(T item) imageOf;
  final String? Function(T item) badgeOf;
  final VoidCallback Function(T item) onTapOf;
  final double scale;

  const TvVodSimilarRow({
    super.key,
    required this.items,
    required this.titleOf,
    required this.imageOf,
    required this.badgeOf,
    required this.onTapOf,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Más similares',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18 * scale,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: 14 * scale),
      SizedBox(
        height: 154 * scale,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: items.length,
          padding: EdgeInsets.only(right: 24 * scale),
          separatorBuilder: (_, _) => SizedBox(width: 14 * scale),
          itemBuilder: (context, index) {
            final item = items[index];
            final title = titleOf(item);
            final image = imageOf(item);
            final badge = badgeOf(item);
            return TvFocusable(
              onTap: onTapOf(item),
              borderRadius: BorderRadius.circular(8 * scale),
              child: SizedBox(
                width: 216 * scale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8 * scale),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: AppColors.cardElevated,
                              child: image?.trim().isNotEmpty == true
                                  ? CachedNetworkImage(
                                      imageUrl: image!.trim(),
                                      fit: BoxFit.cover,
                                      memCacheWidth: 480,
                                      errorWidget: (_, _, _) =>
                                          _fallback(title),
                                    )
                                  : _fallback(title),
                            ),
                            if (badge?.trim().isNotEmpty == true)
                              Positioned(
                                right: 7 * scale,
                                bottom: 7 * scale,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 7 * scale,
                                    vertical: 3 * scale,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.78),
                                    borderRadius: BorderRadius.circular(
                                      4 * scale,
                                    ),
                                  ),
                                  child: Text(
                                    badge!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9 * scale,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 7 * scale),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11.5 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _fallback(String title) => Center(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        title,
        maxLines: 3,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}
