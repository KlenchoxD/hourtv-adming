import 'package:flutter/material.dart';
import '../models/channel.dart';
import 'hourtv_artwork.dart';

class HourTvWebRelated extends StatelessWidget {
  const HourTvWebRelated({
    super.key,
    required this.channels,
    required this.onOpen,
  });
  final List<Channel> channels;
  final ValueChanged<Channel> onOpen;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - 80) / 6).clamp(130.0, 180.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'También te puede gustar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Historias similares para seguir viendo',
              style: TextStyle(color: Color(0xFFA8ADAB), fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: width * 1.5 + 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: channels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final c = channels[index];
                  final genre = (c.genre ?? '')
                      .split(RegExp(r'[,/|]'))
                      .first
                      .trim();
                  final meta = [
                    if (c.year?.trim().isNotEmpty ?? false) c.year!.trim(),
                    if (genre.isNotEmpty) genre,
                  ].join(' · ');
                  final rating = double.tryParse(
                    (c.rating ?? '').replaceAll(',', '.'),
                  );
                  return SizedBox(
                    width: width,
                    child: InkWell(
                      onTap: () => onOpen(c),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 2 / 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const ColoredBox(color: Color(0xFF101412)),
                                  AdaptiveArtwork(
                                    url: c.logo,
                                    fit: BoxFit.contain,
                                    adaptive: true,
                                    cacheWidth: 480,
                                    fallback: const Center(
                                      child: Icon(
                                        Icons.movie_outlined,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                  if (rating != null &&
                                      rating > 0 &&
                                      rating <= 10)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Color(0xFFFFD45A),
                                              size: 15,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                color: Color(0xFFFFD45A),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          SizedBox(
                            height: 36,
                            child: Text(
                              c.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (meta.isNotEmpty)
                            Text(
                              meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFA8ADAB),
                                fontSize: 12,
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
      },
    );
  }
}
