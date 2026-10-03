import 'package:flutter/material.dart';
import '../models/channel.dart';
import 'hourtv_detail_parts.dart';
import '../mobile_ui/hourtv_mobile_components.dart';

class HourTvWebDetailOverview extends StatefulWidget {
  const HourTvWebDetailOverview({
    super.key,
    required this.channel,
    required this.actions,
  });
  final Channel channel;
  final Widget actions;
  @override
  State<HourTvWebDetailOverview> createState() => _OverviewState();
}

class _OverviewState extends State<HourTvWebDetailOverview> {
  bool expanded = false;
  Channel get c => widget.channel;
  static const accent = Color(0xFF00C781);
  Widget text(
    String value, {
    double size = 16,
    bool bold = false,
    Color color = Colors.white,
  }) => Text(
    value,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final series = c.forcedType == 'series';
    final plot = c.plot?.trim() ?? '';
    final cast = c.cast?.trim() ?? '';
    final names = cast.toLowerCase() == plot.toLowerCase()
        ? <String>[]
        : cast
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
    final genres = (c.genre ?? '')
        .split(RegExp(r'[,;/·]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text(
          series ? 'SERIE' : 'PELÍCULA',
          size: 12,
          bold: true,
          color: accent,
        ),
        const SizedBox(height: 12),
        text(c.displayName, size: 38, bold: true),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            if ((c.rating ?? '').isNotEmpty)
              text('★ ${c.rating}', color: Colors.amber),
            if ((c.year ?? '').isNotEmpty) text(c.year!),
            if (hourTvPrettyDuration(c.duration) != null)
              text(hourTvPrettyDuration(c.duration)!),
          ],
        ),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genres
                .map(
                  (g) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .08),
                      border: Border.all(color: accent.withValues(alpha: .3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: text(g, size: 13),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 22),
        widget.actions,
        if (plot.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            plot,
            maxLines: expanded ? null : 4,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD0D4D2),
              fontSize: 17,
              height: 1.6,
            ),
          ),
          if (plot.length > 180)
            TextButton(
              onPressed: () => setState(() => expanded = !expanded),
              child: Text(
                expanded ? 'Ver menos' : 'Ver sinopsis completa',
                style: const TextStyle(color: accent),
              ),
            ),
        ],
      ],
    );
    final about = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xD9101412),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text(
            series ? 'Sobre la serie' : 'Sobre la película',
            size: 20,
            bold: true,
          ),
          if ((c.director ?? '').trim().isNotEmpty)
            field('Dirección', c.director!),
          if ((c.releaseDate ?? c.year ?? '').trim().isNotEmpty)
            field('Estreno', c.releaseDate ?? c.year!),
          if (hourTvPrettyDuration(c.duration) != null)
            field('Duración', hourTvPrettyDuration(c.duration)!),
          field('Tipo', series ? 'Serie' : 'Película'),
        ],
      ),
    );
    final poster = AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: c.logo?.isNotEmpty == true
            ? HourTvArtwork(url: c.logo!)
            : const ColoredBox(
                color: Color(0xFF151917),
                child: Icon(
                  Icons.movie_outlined,
                  color: Colors.white24,
                  size: 64,
                ),
              ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 32),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constraints.maxWidth >= 1000)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: constraints.maxWidth * .22, child: poster),
                  const SizedBox(width: 28),
                  Expanded(child: info),
                  const SizedBox(width: 28),
                  SizedBox(width: constraints.maxWidth * .21, child: about),
                ],
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: constraints.maxWidth * .25, child: poster),
                  const SizedBox(width: 20),
                  Expanded(child: info),
                ],
              ),
              const SizedBox(height: 24),
              about,
            ],
            if (names.isNotEmpty) ...[
              const SizedBox(height: 30),
              const Divider(color: Colors.white12),
              const SizedBox(height: 20),
              text('Reparto principal', size: 24, bold: true),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: names
                    .map(
                      (name) => Container(
                        width: constraints.maxWidth >= 1000
                            ? (constraints.maxWidth - 60) / 6
                            : 240,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xCC101412),
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF24382F),
                              foregroundColor: Colors.white,
                              child: Text(
                                name
                                    .split(RegExp(r'\s+'))
                                    .take(2)
                                    .map((p) => p.substring(0, 1))
                                    .join(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: text(name, size: 14, bold: true)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget field(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        text(label, size: 12, color: Colors.white54),
        const SizedBox(height: 8),
        text(value, size: 14, bold: true),
      ],
    ),
  );
}
