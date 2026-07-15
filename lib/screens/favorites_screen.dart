import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/content_store.dart';
import '../services/device_type.dart';
import '../theme/app_theme.dart';
import '../widgets/tv_focusable.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';

/// Pantalla de FAVORITOS: grilla de películas/canales marcados con corazón
/// (estilo UltraPelis: 3 columnas centradas en móvil, más en TV).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _store = ContentStore.instance;

  double get _s => DeviceProfile.uiScale(context);

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
  }

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _play(Channel ch) {
    final favs = _store.favorites;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlayerScreen(channel: ch, allChannels: favs.isEmpty ? [ch] : favs),
      ),
    );
  }

  void _open(Channel ch) {
    if (ch.type == MediaType.movie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MovieDetailScreen(channel: ch, allChannels: _store.movies),
        ),
      );
      return;
    }
    _play(ch);
  }

  @override
  Widget build(BuildContext context) {
    final favs = _store.favorites;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              8 + DeviceProfile.overscan(context),
              8,
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
                  'Favoritos',
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
            child: favs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          color: AppColors.textMuted,
                          size: 56 * _s,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No tienes favoritos aún',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15 * _s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Marca películas o canales con el corazón\npara verlos aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5 * _s,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16 + DeviceProfile.overscan(context),
                      4,
                      16 + DeviceProfile.overscan(context),
                      24,
                    ),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130 * _s,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: favs.length,
                    itemBuilder: (ctx, i) => _card(favs[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(Channel ch, int index) => TvFocusable(
    onTap: () => _open(ch),
    autofocus: index == 0 && DeviceProfile.isTv(context),
    borderRadius: BorderRadius.circular(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              color: AppColors.cardElevated,
              child: ch.logo != null && ch.logo!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: ch.logo!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _ph(ch),
                    )
                  : _ph(ch),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ch.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12 * _s,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _ph(Channel ch) => Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.cardElevated, AppColors.cardDark],
      ),
    ),
    child: Text(
      ch.displayName,
      maxLines: 4,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.accentLight,
        fontSize: 11 * _s,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
