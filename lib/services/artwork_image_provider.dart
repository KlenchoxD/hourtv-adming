import 'package:flutter/painting.dart';

/// Decode within a memory budget without changing the source's proportions.
/// BoxFit belongs to layout/painting, not to destructive image decoding.
ImageProvider hourTvArtworkProvider(
  ImageProvider provider, {
  int? cacheWidth,
  int? cacheHeight,
}) {
  if (cacheWidth == null && cacheHeight == null) return provider;
  return ResizeImage(
    provider,
    width: cacheWidth,
    height: cacheHeight,
    policy: ResizeImagePolicy.fit,
  );
}
