import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// Tarjeta de canal estilo streaming premium (usada en el grid principal).
class ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final bool isPlaying;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.onFavorite,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: AppTheme.glassCard(active: isPlaying),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                // Zona del logo con halo de color
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.accent.withValues(
                                  alpha: isPlaying ? 0.22 : 0.10,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: _logo(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Pie con nombre
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: const BoxDecoration(color: Colors.black26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPlaying
                              ? AppColors.accentLight
                              : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((channel.epgLine ?? channel.group) != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          channel.epgLine ?? channel.group!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Badge LIVE arriba-izquierda
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.live,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, color: Colors.white, size: 6),
                    SizedBox(width: 3),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Boton de favorito arriba-derecha
            if (onFavorite != null)
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    channel.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: channel.isFavorite
                        ? AppColors.accent
                        : Colors.white70,
                  ),
                  onPressed: onFavorite,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logo() {
    if (channel.logo != null && channel.logo!.isNotEmpty) {
      return Hero(
        tag: 'logo_${channel.url}',
        child: CachedNetworkImage(
          imageUrl: channel.logo!,
          fit: BoxFit.contain,
          placeholder: (_, _) => _placeholder(),
          errorWidget: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardElevated, AppColors.cardDark],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          channel.displayName.isNotEmpty
              ? channel.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: AppColors.accentLight,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Fila compacta de canal (usada en listas verticales).
class ChannelListTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final bool isPlaying;
  final VoidCallback? onFavorite;

  const ChannelListTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.isPlaying = false,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlaying ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: channel.logo != null
            ? CachedNetworkImage(
                imageUrl: channel.logo!,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => _initial(),
              )
            : _initial(),
      ),
      title: Text(
        channel.displayName,
        style: TextStyle(
          color: isPlaying ? AppColors.accentLight : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: (channel.epgLine ?? channel.group) != null
          ? Text(
              channel.epgLine ?? channel.group!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: IconButton(
        icon: Icon(
          channel.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: channel.isFavorite ? AppColors.accent : AppColors.textMuted,
          size: 20,
        ),
        onPressed: onFavorite,
      ),
    );
  }

  Widget _initial() => Center(
    child: Text(
      channel.displayName.isNotEmpty
          ? channel.displayName[0].toUpperCase()
          : '?',
      style: const TextStyle(
        color: AppColors.accentLight,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
