import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/playback_progress.dart';
import 'hourtv_detail_parts.dart' show hourTvPrettyDuration;

const _accent = Color(0xFF00C781);
const _muted = Color(0xFFA8ADAB);
const _line = Color(0xFF27302C);

/// Compact episode rows and the continue-first card share the same artwork,
/// metadata and progress treatment. Playback remains owned by the detail page.
class HourTvEpisodeTile extends StatelessWidget {
  const HourTvEpisodeTile({
    super.key,
    required this.episode,
    required this.number,
    required this.onPlay,
    this.saved,
    this.seriesCover,
    this.seriesBackdrop,
    this.featured = false,
  });

  final Channel episode;
  final int number;
  final VoidCallback onPlay;
  final SavedPosition? saved;
  final String? seriesCover;
  final String? seriesBackdrop;
  final bool featured;

  String get _title {
    final name = episode.displayName.trim();
    final generic = RegExp(
      r'^(episodio|cap[ií]tulo)\s*\d+$',
      caseSensitive: false,
    ).hasMatch(name);
    return generic || name.isEmpty ? 'Episodio $number' : '$number. $name';
  }

  String? get _still {
    for (final candidate in [episode.backdrop, episode.logo]) {
      final image = candidate?.trim();
      if (image != null &&
          image.isNotEmpty &&
          image != seriesCover &&
          image != seriesBackdrop) {
        return image;
      }
    }
    return null;
  }

  double get _fraction =>
      (saved?.fraction ?? episode.progressFraction ?? 0).clamp(0.0, 1.0);
  bool get _completed => saved?.isCompleted ?? _fraction >= .95;
  String? get _remaining {
    if (_completed || _fraction <= 0) return null;
    final position = saved;
    if (position == null || position.durationMs <= 0) return 'En progreso';
    final minutes = ((position.durationMs - position.positionMs) / 60000)
        .ceil();
    return minutes > 0 ? 'Quedan $minutes min' : 'Casi terminado';
  }

  Widget _numberArtwork() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF202725), Color(0xFF101412)],
      ),
    ),
    child: Align(
      alignment: const Alignment(-.75, .7),
      child: Text(
        number.toString().padLeft(2, '0'),
        style: TextStyle(
          color: const Color(0x35FFFFFF),
          fontSize: featured ? 48 : 30,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _artwork() {
    final still = _still;
    return ClipRRect(
      borderRadius: BorderRadius.circular(featured ? 10 : 8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (still != null)
            CachedNetworkImage(
              imageUrl: still,
              fit: BoxFit.cover,
              memCacheWidth: featured ? 480 : 280,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => _numberArtwork(),
              errorWidget: (_, _, _) => _numberArtwork(),
            )
          else
            _numberArtwork(),
          Center(
            child: Container(
              width: featured ? 40 : 30,
              height: featured ? 40 : 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x8C000000),
                border: Border.all(color: const Color(0xE6FFFFFF), width: 1.3),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: featured ? 26 : 21,
              ),
            ),
          ),
          if (_fraction > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: _fraction,
                minHeight: 3,
                color: _accent,
                backgroundColor: const Color(0xAA161B18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metadata() {
    final duration = hourTvPrettyDuration(episode.duration);
    final remaining = _remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: featured ? 15 : 14,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (duration != null) ...[
          const SizedBox(height: 4),
          Text(duration, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
        if (_completed) ...[
          const SizedBox(height: 4),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, color: _accent, size: 16),
              SizedBox(width: 4),
              Text('Visto', style: TextStyle(color: _accent, fontSize: 11.5)),
            ],
          ),
        ] else if (remaining != null) ...[
          const SizedBox(height: 4),
          Text(
            remaining,
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ],
        if (!featured && (episode.plot?.trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 5),
          Text(
            episode.plot!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.35),
          ),
        ],
        if (featured) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPlay,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'Continuar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(featured ? 12 : 8);
    return Semantics(
      button: true,
      label: _title,
      child: Material(
        color: featured ? const Color(0xFF101412) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: featured ? const BorderSide(color: _line) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPlay,
          borderRadius: radius,
          child: Padding(
            padding: featured
                ? const EdgeInsets.all(10)
                : const EdgeInsets.symmetric(vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  SizedBox(
                    width: featured
                        ? (constraints.maxWidth - 12) * .46
                        : (constraints.maxWidth < 320 ? 90 : 104),
                    height: featured ? 136 : 70,
                    child: _artwork(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _metadata()),
                  if (!featured) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _muted,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
