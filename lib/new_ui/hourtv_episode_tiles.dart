import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/playback_progress.dart';
import 'hourtv_detail_parts.dart' show hourTvPrettyDuration;

const _accent = Color(0xFF00C781);
const _muted = Color(0xFFA8ADAB);

/// Landscape episode artwork with readable metadata and per-episode progress.
/// Playback remains owned by the detail page.
class HourTvEpisodeTile extends StatelessWidget {
  const HourTvEpisodeTile({
    super.key,
    required this.episode,
    required this.number,
    required this.onPlay,
    this.saved,
    this.seriesCover,
    this.seriesBackdrop,
  });

  final Channel episode;
  final int number;
  final VoidCallback onPlay;
  final SavedPosition? saved;
  final String? seriesCover;
  final String? seriesBackdrop;

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
        style: const TextStyle(
          color: Color(0x35FFFFFF),
          fontSize: 40,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _artwork() {
    final still = _still;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (still != null)
            CachedNetworkImage(
              imageUrl: still,
              fit: BoxFit.cover,
              memCacheWidth: 480,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => _numberArtwork(),
              errorWidget: (_, _, _) => _numberArtwork(),
            )
          else
            _numberArtwork(),
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x8C000000),
                border: Border.all(color: const Color(0xE6FFFFFF), width: 1.3),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
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
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _fraction,
              minHeight: 4,
              color: _accent,
              backgroundColor: const Color(0xFF343937),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            remaining,
            style: const TextStyle(color: _muted, fontSize: 11.5),
          ),
        ],
        if (episode.plot?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 7),
          Text(
            episode.plot!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.35),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return Semantics(
      button: true,
      label: _title,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPlay,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: (constraints.maxWidth - 12) * .48,
                    height: (constraints.maxWidth - 12) * .48 / 1.6,
                    child: _artwork(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _metadata()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
