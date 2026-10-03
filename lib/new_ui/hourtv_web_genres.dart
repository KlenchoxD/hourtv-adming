import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../mobile_ui/hourtv_genre_service.dart';
import '../mobile_ui/hourtv_mobile_components.dart' show HourTvArtwork;
import '../services/content_store.dart';
import '../services/catalog/catalog_detail_navigator.dart';

/// Compact genre shortcuts, confined to the web detail layout.
class HourTvWebGenres extends StatefulWidget {
  const HourTvWebGenres({super.key, required this.genres, this.onSelect});
  final List<String> genres;
  final ValueChanged<String>? onSelect;
  @override
  State<HourTvWebGenres> createState() => _GenresState();
}

class _GenresState extends State<HourTvWebGenres> {
  int? active;
  (String, Color) style(String genre) {
    final key = HourTvGenreService.normalize(genre);
    if (key.contains('terror') || key.contains('horror')) {
      return ('👻', const Color(0xFFB0A6BC));
    }
    if (key.contains('mister') || key.contains('crimen')) {
      return ('🔎', const Color(0xFF48B5AD));
    }
    if (key.contains('ficcion') || key.contains('fantas')) {
      return ('🪐', const Color(0xFFA87BD7));
    }
    if (key.contains('accion') || key.contains('aventura')) {
      return ('⚔️', const Color(0xFFEE6868));
    }
    if (key.contains('comedia')) {
      return ('🎭', const Color(0xFFE7B65A));
    }
    if (key.contains('romance')) {
      return ('♥', const Color(0xFFE88BB5));
    }
    return ('🎬', const Color(0xFF7AAED7));
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onExit: (_) => setState(() => active = null),
    child: Focus(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = widget.genres.length;
          if (count == 0) return const SizedBox.shrink();
          // Keep every shortcut reachable, even with many genres or a small window.
          const spacing = 30.0;
          final width = 110.0 + (count - 1) * spacing;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: width,
              height: 54,
              child: Stack(
                children: [
                  for (var i = count - 1; i >= 0; i--)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      left: i * spacing,
                      top: 0,
                      width: 36,
                      child: Builder(
                        builder: (context) {
                          final genre = widget.genres[i];
                          final (icon, color) = style(genre);
                          return MouseRegion(
                            onEnter: (_) => setState(() => active = i),
                            child: Focus(
                              onFocusChange: (value) =>
                                  setState(() => active = value ? i : null),
                              child: Semantics(
                                label: 'Explorar $genre',
                                button: true,
                                child: InkWell(
                                  key: ValueKey('genre-$genre'),
                                  borderRadius: BorderRadius.circular(26),
                                  onTap: () {
                                    if (widget.onSelect != null) {
                                      widget.onSelect!(genre);
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              HourTvWebGenrePage(genre: genre),
                                        ),
                                      );
                                    }
                                  },
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: color.withValues(alpha: .7),
                                          ),
                                          gradient: RadialGradient(
                                            colors: [
                                              color.withValues(alpha: .22),
                                              const Color(0xEE101412),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            icon,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 21,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (active != null)
                    Positioned(
                      left: 0,
                      top: 37,
                      child: IgnorePointer(
                        child: Text(
                          widget.genres[active!],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

List<Channel> hourTvWebGenreResults(Iterable<Channel> content, String genre) =>
    content
        .where(
          (c) =>
              c.type != MediaType.live &&
              HourTvGenreService.channelMatchesGenre(c, genre),
        )
        .toList();

class HourTvWebGenrePage extends StatelessWidget {
  const HourTvWebGenrePage({super.key, required this.genre});
  final String genre;
  @override
  Widget build(BuildContext context) {
    final store = ContentStore.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: Text(genre),
        backgroundColor: const Color(0xFF101412),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final items = hourTvWebGenreResults([
            ...store.movies,
            ...store.seriesChannels,
          ], genre);
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No hay títulos disponibles de este género.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(32),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 24,
              crossAxisSpacing: 20,
              childAspectRatio: .59,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final c = items[i];
              return InkWell(
                onTap: () => CatalogDetailNavigator.openDetails(context, c),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: HourTvArtwork(
                          url: c.logo ?? '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      c.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
