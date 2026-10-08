import 'package:flutter/material.dart';
import '../services/anime_schedule_service.dart';
import '../services/xtream_service.dart';

class HourTvAnimeStatusBadge extends StatefulWidget {
  const HourTvAnimeStatusBadge({super.key, required this.series});
  final XtreamSeries series;
  @override
  State<HourTvAnimeStatusBadge> createState() => _HourTvAnimeStatusBadgeState();
}

class _HourTvAnimeStatusBadgeState extends State<HourTvAnimeStatusBadge> {
  late Future<AnimeAiringMedia?> _future = AnimeScheduleService.instance.lookup(
    widget.series,
  );
  @override
  void didUpdateWidget(covariant HourTvAnimeStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series.seriesId != widget.series.seriesId) {
      _future = AnimeScheduleService.instance.lookup(widget.series);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AnimeAiringMedia?>(
    future: _future,
    builder: (context, snapshot) {
      final label = snapshot.data?.statusLabel;
      if (label == null) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0B3024),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00C781),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    },
  );
}
