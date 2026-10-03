import 'package:flutter/material.dart';
import '../models/channel.dart';
import 'hourtv_detail_parts.dart';
import '../mobile_ui/hourtv_mobile_components.dart';
import 'hourtv_web_genres.dart';

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
              .take(6)
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
          HourTvWebGenres(genres: genres.toList()),
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
      padding: const EdgeInsets.only(left: 12, top: 8),
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
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constraints.maxWidth >= 1000)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: constraints.maxWidth * .29, child: poster),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        info,
                        if (names.isNotEmpty) castSection(names),
                      ],
                    ),
                  ),
                  const SizedBox(width: 28),
                  SizedBox(width: constraints.maxWidth * .20, child: about),
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
              if (names.isNotEmpty) castSection(names),
            ],
          ],
        ),
      ),
    );
  }

  Widget castSection(List<String> names) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text('Reparto principal', size: 22, bold: true),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 540
                ? (constraints.maxWidth - 50) / 6
                : 88.0;
            return Wrap(
              spacing: 10,
              runSpacing: 18,
              children: names
                  .map(
                    (name) => SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: width.clamp(56, 100) / 2,
                            backgroundColor: const Color(0xFF303735),
                            foregroundColor: Colors.white,
                            child: Text(
                              name
                                  .split(RegExp(r'\s+'))
                                  .take(2)
                                  .map((p) => p.substring(0, 1))
                                  .join(),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

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
