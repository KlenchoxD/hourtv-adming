import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../new_ui/hourtv_profile_avatar.dart';
import '../services/update_service.dart';
import 'hourtv_mobile_theme.dart';

/// Marca de HourTV: "Hour" en blanco y "TV" dentro de una pastilla verde
/// solida. Antes eran las dos palabras en texto plano a 20px, del mismo peso
/// que cualquier titulo de la pantalla: se perdia en el header y no se leia
/// como un logo. La pastilla + el peso extra le dan el contraste que le
/// faltaba.
class HourTvLogo extends StatelessWidget {
  const HourTvLogo({super.key, this.fontSize = 26});

  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        'Hour',
        style: TextStyle(
          color: HourTvMobileTokens.textPrimary,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
      ),
      SizedBox(width: fontSize * 0.14),
      DecoratedBox(
        decoration: BoxDecoration(
          color: HourTvMobileTokens.emerald,
          borderRadius: BorderRadius.circular(fontSize * 0.3),
          boxShadow: [
            BoxShadow(
              color: HourTvMobileTokens.emerald.withValues(alpha: .45),
              blurRadius: fontSize * 0.5,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.22,
            vertical: fontSize * 0.1,
          ),
          child: Text(
            'TV',
            style: TextStyle(
              color: HourTvMobileTokens.deepBlack,
              fontSize: fontSize * 0.82,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Pantalla de carga con marca: antes era un CircularProgressIndicator
/// suelto sin contexto. Con el logo, un halo suave, una barra de progreso
/// indeterminada y un mensaje se entiende que la app sigue viva en vez de
/// que se colgó. Se reusa en dos momentos con textos distintos: el arranque
/// de la app ("Preparando el app para usar") y, ya adentro, mientras el
/// catalogo real todavia llega ("Cargando catálogo").
class HourTvBootLoading extends StatelessWidget {
  const HourTvBootLoading({
    super.key,
    this.title = 'Cargando catálogo',
    this.subtitle = 'Un momento, estamos casi listos.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: HourTvMobileTokens.emerald.withValues(alpha: .18),
                  blurRadius: 40,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: const HourTvLogo(fontSize: 34),
          ),
          const SizedBox(height: 28),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 180,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HourTvMobileTokens.surfaceControl,
                  border: Border.all(color: HourTvMobileTokens.borderSubtle),
                ),
                child: const LinearProgressIndicator(
                  color: HourTvMobileTokens.emerald,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: HourTvMobileTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HourTvMobileTokens.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}

class HourTvMobileHeader extends StatelessWidget {
  const HourTvMobileHeader({
    super.key,
    this.title,
    this.showLogo = true,
    this.onAvatarTap,
    this.trailing,
    this.profileName = 'Invitado',
    this.avatarSeed,
  });

  final String? title;
  final bool showLogo;
  final VoidCallback? onAvatarTap;
  final Widget? trailing;
  final String profileName;
  final String? avatarSeed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HourTvMobileTokens.horizontalPadding,
      ),
      child: Row(
        children: [
          if (showLogo)
            const HourTvLogo()
          else
            Text(title ?? '', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          ?trailing,
          const SizedBox(width: 10),
          Semantics(
            button: true,
            label: 'Perfil',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onAvatarTap,
              child: HourTvProfileAvatar(
                profileName: profileName,
                avatarSeed: avatarSeed,
                radius: 18,
                backgroundColor: HourTvMobileTokens.emerald,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class HourTvBottomDestination {
  const HourTvBottomDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

class HourTvBottomNavigation extends StatelessWidget {
  const HourTvBottomNavigation({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  static const destinations = [
    HourTvBottomDestination(Icons.home_outlined, 'Inicio'),
    HourTvBottomDestination(Icons.live_tv_outlined, 'TV'),
    HourTvBottomDestination(Icons.search_rounded, 'Buscar'),
    HourTvBottomDestination(Icons.bookmark_border_rounded, 'Mi Biblioteca'),
    HourTvBottomDestination(Icons.person_outline_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: HourTvMobileTokens.background,
      border: Border(top: BorderSide(color: HourTvMobileTokens.borderSubtle)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: HourTvMobileTokens.bottomNavigationHeight,
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: Semantics(
                  selected: index == i,
                  button: true,
                  label: destinations[i].label,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              destinations[i].icon,
                              size: 20,
                              color: index == i
                                  ? HourTvMobileTokens.emerald
                                  : HourTvMobileTokens.textMuted,
                            ),
                            // Punto de actualizacion disponible, solo en
                            // "Perfil": ahi vive la pantalla que la instala.
                            if (destinations[i].label == 'Perfil')
                              Positioned(
                                top: -2,
                                right: -3,
                                child: ValueListenableBuilder<bool>(
                                  valueListenable:
                                      UpdateService.instance.hasUpdateAvailable,
                                  builder: (context, hasUpdate, _) =>
                                      hasUpdate
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: HourTvMobileTokens.emerald,
                                            border: Border.all(
                                              color:
                                                  HourTvMobileTokens.background,
                                              width: 2,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            destinations[i].label.toUpperCase(),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.4,
                              color: index == i
                                  ? HourTvMobileTokens.emerald
                                  : HourTvMobileTokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Boton principal (CTA) del hero: pildora solida con sombra, para que
/// destaque en vez de verse como un rectangulo plano mas.
class HourTvButton extends StatelessWidget {
  const HourTvButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HourTvMobileTokens.minimumTouchTarget,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.fade,
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: HourTvMobileTokens.emerald,
          foregroundColor: HourTvMobileTokens.deepBlack,
          disabledBackgroundColor: HourTvMobileTokens.surfaceControl,
          elevation: 4,
          shadowColor: HourTvMobileTokens.emerald.withValues(alpha: .5),
          shape: const StadiumBorder(),
          // El labelLarge global (12px, pensado para botones chicos como
          // "Ver más") se veia insignificante en el CTA principal del hero.
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}

class HourTvChip extends StatelessWidget {
  const HourTvChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        constraints: const BoxConstraints(minWidth: 72, maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? HourTvMobileTokens.emerald
              : HourTvMobileTokens.surfaceControl,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: HourTvMobileTokens.borderSubtle),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? HourTvMobileTokens.deepBlack
                : HourTvMobileTokens.textSecondary,
          ),
        ),
      ),
    ),
  );
}

/// Fila de opciones fijas repartidas en el ancho completo, sin scroll: para
/// grupos chicos y conocidos de antemano (pestañas, generos fijos) donde
/// forzar al usuario a arrastrar un carrusel para ver la ultima opcion no
/// tiene sentido. `HourTvChip` sigue siendo lo correcto para listas largas o
/// de tamaño variable (busqueda con historial, por ejemplo).
class HourTvEvenTabs extends StatelessWidget {
  const HourTvEvenTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final label in labels) ...[
        if (label != labels.first) const SizedBox(width: 8),
        Expanded(child: _button(label)),
      ],
    ],
  );

  Widget _button(String label) {
    final active = label == selected;
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: () => onSelected(label),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? HourTvMobileTokens.emerald
                : HourTvMobileTokens.surfaceControl,
            borderRadius: BorderRadius.circular(999),
            border: active
                ? null
                : Border.all(color: HourTvMobileTokens.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            // Roboto Serif es mas ancha que la Inter de antes: con
            // TextOverflow.ellipsis a tamaño fijo, etiquetas como "Continuar
            // viendo" quedaban cortadas en su tercio de la pantalla. Con
            // FittedBox se encoge lo justo para entrar completa en vez de
            // truncarse.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  color: active
                      ? HourTvMobileTokens.deepBlack
                      : HourTvMobileTokens.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HourTvSectionHeader extends StatelessWidget {
  const HourTvSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(letterSpacing: .3),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: HourTvMobileTokens.emerald,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(48, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '${actionLabel!.toUpperCase()}  ›',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );
}

class HourTvArtwork extends StatelessWidget {
  const HourTvArtwork({
    super.key,
    this.url,
    this.asset,
    this.fit = BoxFit.cover,
    // El centro por defecto sirve para backdrops horizontales reales, pero
    // cuando no hay backdrop y se usa el poster (vertical) como respaldo en
    // una caja horizontal, centrar corta justo la cara del protagonista.
    // topCenter deja ver la parte alta del poster, donde suele estar la cara.
    this.alignment = Alignment.center,
    this.borderRadius,
  });

  final String? url;
  final String? asset;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url?.trim();
    final image = cleanUrl != null && cleanUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: cleanUrl,
            fit: fit,
            alignment: alignment,
            fadeInDuration: const Duration(milliseconds: 120),
            placeholder: (_, _) =>
                const ColoredBox(color: HourTvMobileTokens.surfacePrimary),
            errorWidget: (_, _, _) => _fallback(),
          )
        : asset != null
        ? Image.asset(
            asset!,
            fit: fit,
            alignment: alignment,
            errorBuilder: (_, _, _) => _fallback(),
          )
        : _fallback();
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox.expand(child: image),
    );
  }

  Widget _fallback() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF16201C), Color(0xFF080A09)],
      ),
    ),
    child: Center(
      child: Icon(Icons.movie_outlined, color: HourTvMobileTokens.textMuted),
    ),
  );
}

class HourTvPosterCard extends StatefulWidget {
  const HourTvPosterCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.width = 120,
    this.assetFallback,
  });

  final Channel channel;
  final VoidCallback onTap;
  final double width;
  final String? assetFallback;

  @override
  State<HourTvPosterCard> createState() => _HourTvPosterCardState();
}

class _HourTvPosterCardState extends State<HourTvPosterCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? 0.97 : 1.0,
    duration: const Duration(milliseconds: 150),
    curve: Curves.easeOut,
    child: SizedBox(
      width: widget.width,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 120 / 178,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: HourTvMobileTokens.borderSubtle),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HourTvArtwork(
                  url: widget.channel.logo,
                  asset: widget.assetFallback,
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 15 / 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [widget.channel.year, widget.channel.genre ?? widget.channel.group]
                  .whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HourTvMobileTokens.textMuted,
                fontSize: 11,
                height: 14 / 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
