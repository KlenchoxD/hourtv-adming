import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';

/// Contenido reproducido recientemente, accesible desde Perfil.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Channel> _recent = const [];

  double get _s => DeviceProfile.uiScale(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _recent = StorageService.loadRecent();
  }

  Future<void> _open(Channel channel) async {
    if (channel.type == MediaType.movie) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(
            channel: channel,
            allChannels: ContentStore.instance.movies,
          ),
        ),
      );
    } else {
      final sameType = _recent
          .where((item) => item.type == channel.type)
          .toList(growable: false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            channel: channel,
            allChannels: sameType.isEmpty ? [channel] : sameType,
          ),
        ),
      );
    }
    if (!mounted) return;
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              12 + DeviceProfile.overscan(context),
              10,
              18,
              10,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Volver',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Historial',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20 * _s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _recent.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: AppColors.textMuted,
                          size: 56 * _s,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Todavía no hay reproducciones',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15 * _s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lo que veas aparecerá aquí.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5 * _s,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      18 + DeviceProfile.overscan(context),
                      4,
                      18 + DeviceProfile.overscan(context),
                      24,
                    ),
                    itemCount: _recent.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _item(_recent[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _item(Channel channel, int index) {
    final logo = channel.backdrop?.isNotEmpty == true
        ? channel.backdrop!
        : channel.logo;
    return TvFocusable(
      onTap: () => _open(channel),
      autofocus: index == 0 && DeviceProfile.isTv(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 92 * _s,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 122 * _s,
                height: double.infinity,
                child: logo != null && logo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logo,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _placeholder(channel),
                      )
                    : _placeholder(channel),
              ),
            ),
            SizedBox(width: 13 * _s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    channel.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14 * _s,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _subtitle(channel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5 * _s,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.accent,
              size: 30 * _s,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Channel channel) {
    return Container(
      color: AppColors.cardElevated,
      alignment: Alignment.center,
      child: Icon(
        channel.type == MediaType.live
            ? Icons.live_tv_rounded
            : Icons.movie_rounded,
        color: AppColors.textMuted,
        size: 30 * _s,
      ),
    );
  }

  String _subtitle(Channel channel) {
    final type = switch (channel.type) {
      MediaType.live => 'En vivo',
      MediaType.movie => 'Película',
      MediaType.series => 'Episodio',
    };
    final watched = channel.lastWatched;
    if (watched == null) return type;
    final elapsed = DateTime.now().difference(watched);
    if (elapsed.inMinutes < 1) return '$type · ahora';
    if (elapsed.inHours < 1) return '$type · hace ${elapsed.inMinutes} min';
    if (elapsed.inDays < 1) return '$type · hace ${elapsed.inHours} h';
    return '$type · hace ${elapsed.inDays} d';
  }
}
