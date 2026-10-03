import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../mobile_ui/hourtv_compact_filter_selector.dart';
import 'hourtv_artwork.dart';
import 'hourtv_web_feedback.dart';

/// Desktop channel navigation, separate from the native phone guide.
class HourTvWebChannelGuide extends StatefulWidget {
  const HourTvWebChannelGuide({
    super.key,
    required this.channels,
    required this.currentUrl,
    required this.onSelect,
    required this.onFavorite,
  });
  final List<Channel> channels;
  final String currentUrl;
  final ValueChanged<Channel> onSelect, onFavorite;
  @override
  State<HourTvWebChannelGuide> createState() => _ChannelGuideState();
}

class _ChannelGuideState extends State<HourTvWebChannelGuide> {
  String query = '', category = 'Todas';
  bool favorites = false;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void _filter(VoidCallback change) {
    setState(change);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  String _category(Channel c) => (c.genre ?? c.group ?? '').trim();
  static const green = Color(0xFF00C781);
  static const line = Color(0xFF27302C);

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Todas',
      ...widget.channels
          .map(_category)
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];
    final selectedCategory = categories.contains(category) ? category : 'Todas';
    final items = widget.channels
        .where(
          (c) =>
              (!favorites || c.isFavorite) &&
              (selectedCategory == 'Todas' ||
                  _category(c) == selectedCategory) &&
              c.displayName.toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF090D0B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Canales en vivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                ),
                Text(
                  '${items.length} ${items.length == 1 ? 'canal' : 'canales'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: TextField(
                onChanged: (v) => _filter(() => query = v),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar canal…',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Color(0xFFA6A6B0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101412),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  for (final fav in [false, true])
                    Expanded(
                      child: HourTvWebFeedback(
                        child: Material(
                          color: favorites == fav ? green : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () => _filter(() => favorites = fav),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Text(
                                fav ? 'Favoritos' : 'Todos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: favorites == fav
                                      ? Colors.black
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            HourTvCompactFilterSelector(
              label: 'Categoría',
              value: selectedCategory,
              options: categories,
              icon: Icons.layers_rounded,
              onChanged: (v) => _filter(() => category = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay canales con estos filtros.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      itemExtent: 84,
                      itemCount: items.length,
                      itemBuilder: (_, i) => _row(items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Channel c) {
    final active = c.url == widget.currentUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HourTvWebFeedback(
        child: Material(
          color: active ? const Color(0xFF0C2119) : const Color(0xFF101412),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => widget.onSelect(c),
            borderRadius: BorderRadius.circular(10),
            hoverColor: Colors.white.withValues(alpha: .04),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? green.withValues(alpha: .45) : line,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? green : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D0B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: line),
                    ),
                    child: AdaptiveArtwork(
                      url: c.logo ?? c.backdrop,
                      fit: BoxFit.contain,
                      fallback: const Icon(
                        Icons.live_tv_rounded,
                        color: Colors.white38,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (active)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.equalizer_rounded,
                                  color: green,
                                  size: 17,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _category(c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: c.isFavorite
                        ? 'Quitar de favoritos'
                        : 'Añadir a favoritos',
                    onPressed: () => widget.onFavorite(c),
                    icon: Icon(
                      c.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: c.isFavorite ? green : Colors.white54,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
