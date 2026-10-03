import 'package:flutter/material.dart';
import '../models/channel.dart';
import 'hourtv_artwork.dart';
import 'hourtv_web_feedback.dart';
import '../mobile_ui/hourtv_compact_filter_selector.dart';

class HourTvWebLibrary extends StatefulWidget {
  const HourTvWebLibrary({
    super.key,
    required this.items,
    required this.tab,
    required this.onTab,
    required this.onOpen,
    required this.onRemove,
  });
  final List<Channel> items;
  final String tab;
  final ValueChanged<String> onTab;
  final ValueChanged<Channel> onOpen, onRemove;
  @override
  State<HourTvWebLibrary> createState() => _WebLibraryState();
}

class _WebLibraryState extends State<HourTvWebLibrary> {
  String query = '', type = 'Todo', sort = 'Recientes';
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where(
          (c) =>
              c.displayName.toLowerCase().contains(query.toLowerCase()) &&
              (type == 'Todo' ||
                  (type == 'Películas'
                      ? c.type == MediaType.movie
                      : c.type == MediaType.series)),
        )
        .toList();
    if (sort == 'Título A–Z') {
      items.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < 700 ? 20.0 : 56.0;
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 30, pad, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (constraints.maxWidth >= 1100)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: _heading(items.length)),
                          _controls(),
                        ],
                      )
                    else ...[
                      _heading(items.length),
                      const SizedBox(height: 20),
                      _controls(),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final tab in ['Mi Lista', 'Historial'])
                          TextButton(
                            onPressed: () => widget.onTab(tab),
                            style: TextButton.styleFrom(
                              foregroundColor: widget.tab == tab
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tab),
                                const SizedBox(height: 8),
                                Container(
                                  height: 2,
                                  width: 64,
                                  color: widget.tab == tab
                                      ? const Color(0xFF00C781)
                                      : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 12),
                  ],
                ),
              ),
            ),
            if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No hay títulos para mostrar.\nGuarda tus favoritos o cambia los filtros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.8),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 16 / 9,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _card(items[i]),
                    childCount: items.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _heading(int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Tu colección, a tu manera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Mi biblioteca · $count ${count == 1 ? 'título' : 'títulos'}',
        style: const TextStyle(color: Colors.white54),
      ),
    ],
  );

  Widget _controls() => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 260,
        height: 48,
        child: TextField(
          onChanged: (v) => setState(() => query = v),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Buscar en mi biblioteca',
            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFFA6A6B0)),
          ),
        ),
      ),
      _dropdown(sort, [
        'Recientes',
        'Título A–Z',
      ], (v) => setState(() => sort = v)),
      _dropdown(type, [
        'Todo',
        'Películas',
        'Series',
      ], (v) => setState(() => type = v)),
    ],
  );

  Widget _dropdown(
    String value,
    List<String> options,
    ValueChanged<String> changed,
  ) => SizedBox(
    width: 150,
    child: HourTvCompactFilterSelector(
      label: options.contains('Todo') ? 'Tipo' : 'Ordenar',
      value: value,
      icon: options.contains('Todo')
          ? Icons.layers_rounded
          : Icons.sort_rounded,
      options: options,
      onChanged: changed,
    ),
  );
  Widget _card(Channel c) => HourTvWebFeedback(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: const Color(0xFF151917),
        child: InkWell(
          onTap: () => widget.onOpen(c),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AdaptiveArtwork(
                url: c.backdrop?.isNotEmpty == true
                    ? c.backdrop!
                    : c.logo ?? '',
                fit: BoxFit.cover,
                fallback: const Center(
                  child: Icon(
                    Icons.movie_outlined,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xF5000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [c.year, (c.genre ?? '').split(',').first, c.duration]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (widget.tab == 'Historial' &&
                        (c.progressFraction ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: c.progressFraction!.clamp(0, 1),
                        minHeight: 3,
                        color: const Color(0xFF00C781),
                        backgroundColor: Colors.white24,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.tab == 'Mi Lista')
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    tooltip: 'Quitar de mi lista',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: () => widget.onRemove(c),
                    icon: const Icon(
                      Icons.bookmark,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
