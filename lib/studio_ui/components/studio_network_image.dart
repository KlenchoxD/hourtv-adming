import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../foundation/studio_tokens.dart';

class StudioNetworkImage extends StatelessWidget {
  const StudioNetworkImage({
    super.key,
    this.url,
    this.imageProvider,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallbackIcon = Icons.movie_outlined,
  });

  final String? url;
  final ImageProvider<Object>? imageProvider;
  final BoxFit fit;
  final Alignment alignment;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (imageProvider != null) {
      return Image(
        image: imageProvider!,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
      );
    }

    final source = url?.trim() ?? '';
    if (source.isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) =>
          const ColoredBox(color: StudioColors.surfaceElevated),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: StudioColors.surfaceElevated,
      child: Center(
        child: Icon(fallbackIcon, color: StudioColors.textMuted, size: 28),
      ),
    );
  }
}
