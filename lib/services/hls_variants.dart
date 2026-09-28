import 'dart:convert';

import 'subtitles/subtitle_discovery_service.dart';

/// Una calidad de un HLS maestro (#EXT-X-STREAM-INF).
class HlsVariant {
  const HlsVariant({
    required this.height,
    required this.bandwidth,
    required this.url,
  });

  final int height;
  final int bandwidth;
  final String url;

  String get label => '${height}p';
}

/// Calidades reproducibles por separado, de mayor a menor, una por altura.
///
/// ponytail: se descartan las variantes con pista de audio aparte (AUDIO=):
/// reproducidas solas quedarían sin sonido. Para ofrecerlas habría que
/// servir un maestro filtrado en vez de la variante.
List<HlsVariant> parseHlsVariants(String manifest, Uri baseUri) {
  final best = <int, HlsVariant>{};
  Map<String, String>? pending;
  for (final raw in const LineSplitter().convert(manifest)) {
    final line = raw.trim();
    if (line.startsWith('#EXT-X-STREAM-INF:')) {
      pending = SubtitleDiscoveryService.parseAttributes(
        line.substring('#EXT-X-STREAM-INF:'.length),
      );
      continue;
    }
    if (pending == null || line.isEmpty || line.startsWith('#')) continue;
    final attrs = pending;
    pending = null;
    final height = int.tryParse(
      attrs['RESOLUTION']?.toLowerCase().split('x').last ?? '',
    );
    if (height == null || height <= 0 || attrs.containsKey('AUDIO')) continue;
    final url = baseUri.resolve(line);
    if (url.scheme != 'http' && url.scheme != 'https') continue;
    final bandwidth = int.tryParse(attrs['BANDWIDTH'] ?? '') ?? 0;
    final current = best[height];
    if (current == null || bandwidth > current.bandwidth) {
      best[height] = HlsVariant(
        height: height,
        bandwidth: bandwidth,
        url: url.toString(),
      );
    }
  }
  return best.values.toList()..sort((a, b) => b.height.compareTo(a.height));
}
