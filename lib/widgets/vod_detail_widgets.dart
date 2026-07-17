import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/device_type.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';
import 'tv_vod_detail_actions.dart';
import 'tv_vod_similar_row.dart';

class VodDetailAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const VodDetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

class VodSimilarItem {
  final String title;
  final String? imageUrl;
  final String? badge;
  final VoidCallback onTap;

  const VodSimilarItem({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.badge,
  });
}

/// Compara el reparto con la sinopsis ignorando espacios y puntuación.
/// Algunos proveedores copian el argumento completo en el campo de actores.
bool isDistinctDetailCast(String? cast, String? plot) {
  final castValue = cast?.trim();
  if (castValue == null || castValue.isEmpty) return false;
  final plotValue = plot?.trim();
  if (plotValue == null || plotValue.isEmpty) return true;

  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return normalize(castValue) != normalize(plotValue);
}

List<String> splitDetailGenres(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  final seen = <String>{};
  return value
      .split(RegExp(r'[,/|;]+'))
      .map((genre) => genre.trim())
      .where((genre) => genre.isNotEmpty && seen.add(genre.toLowerCase()))
      .take(5)
      .toList();
}

/// Estructura visual única para todos los detalles VOD de HourTV.
/// [body] contiene únicamente la parte específica del tipo de contenido.
class VodDetailView extends StatelessWidget {
  final String title;
  final String? backdropUrl;
  final String? year;
  final String? duration;
  final String? rating;
  final List<String> genres;
  final String? plot;
  final String? director;
  final String? writer;
  final String? cast;
  final double scale;
  final double overscan;
  final VoidCallback onBack;
  final VoidCallback? onPlay;
  final bool playAutofocus;
  final List<VodDetailAction> actions;
  final Widget? body;
  final List<VodSimilarItem> similarItems;

  const VodDetailView({
    super.key,
    required this.title,
    required this.scale,
    required this.overscan,
    required this.onBack,
    required this.onPlay,
    this.backdropUrl,
    this.year,
    this.duration,
    this.rating,
    this.genres = const [],
    this.plot,
    this.director,
    this.writer,
    this.cast,
    this.playAutofocus = false,
    this.actions = const [],
    this.body,
    this.similarItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (DeviceProfile.isTv(context)) return _buildTv(context);
    return _buildPhone(context);
  }

  /// Detalle cinematográfico para TV (10-foot): backdrop a sangre completa de
  /// fondo, la información a la izquierda y el foco inicial en Reproducir.
  Widget _buildTv(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // El área segura de TV equivale al 4-5 % del ancho: evita overscan y deja
    // respirar la composición desde una distancia de visualización real.
    final pad = math.max(size.width * 0.047, math.max(overscan, 42.0));
    final infoWidth = math.min(size.width * 0.40, 690.0);
    return ColoredBox(
      color: AppColors.primaryDark,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Stack(
          children: [
            Positioned.fill(
              child: (backdropUrl?.trim().isNotEmpty == true)
                  ? CachedNetworkImage(
                      imageUrl: backdropUrl!.trim(),
                      fit: BoxFit.cover,
                      alignment: Alignment.topRight,
                      memCacheWidth: 1280,
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: AppColors.cardDark),
                    )
                  : const ColoredBox(color: AppColors.cardDark),
            ),
            // Oscurece la izquierda (donde va el texto) y la base.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF20B0B0B),
                      Color(0xCC0B0B0B),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.42, 0.85],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xF20B0B0B), Colors.transparent],
                    stops: [0.0, 0.55],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: size.height * 0.10),
                    SizedBox(
                      width: infoWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 30 * scale,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 18 * scale),
                          _DetailMetadata(
                            year: year,
                            duration: duration,
                            rating: rating,
                            genres: genres,
                            scale: scale,
                          ),
                          if (plot?.trim().isNotEmpty == true) ...[
                            SizedBox(height: 22 * scale),
                            Text(
                              plot!.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5 * scale,
                                height: 1.4,
                              ),
                            ),
                          ],
                          SizedBox(height: 28 * scale),
                          TvVodDetailPrimaryActions(
                            onPlay: onPlay,
                            autofocus: playAutofocus,
                            scale: scale,
                            secondaryIcon: actions.isEmpty
                                ? null
                                : actions.first.icon,
                            secondaryLabel: actions.isEmpty
                                ? null
                                : actions.first.label,
                            secondarySelected:
                                actions.isNotEmpty && actions.first.selected,
                            onSecondaryTap: actions.isEmpty
                                ? null
                                : actions.first.onTap,
                          ),
                          if (actions.length > 1) ...[
                            SizedBox(height: 16 * scale),
                            Wrap(
                              spacing: 18 * scale,
                              runSpacing: 10 * scale,
                              children: actions
                                  .skip(1)
                                  .map(
                                    (action) => TvVodDetailInlineAction(
                                      icon: action.icon,
                                      label: action.label,
                                      selected: action.selected,
                                      onTap: action.onTap,
                                      scale: scale,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          SizedBox(height: 18 * scale),
                          _DetailFacts(
                            director: director,
                            writer: writer,
                            cast: cast,
                            plot: plot,
                            scale: scale,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30 * scale),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ?body,
                            if (similarItems.isNotEmpty) ...[
                              SizedBox(height: 28 * scale),
                              _SimilarSection(
                                items: similarItems,
                                scale: scale,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: pad * 0.4,
              left: pad * 0.4,
              child: TvFocusable(
                onTap: onBack,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 44 * scale,
                  height: 44 * scale,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 24 * scale,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhone(BuildContext context) {
    final horizontal = math.max(18 * scale, overscan);
    return ColoredBox(
      color: AppColors.primaryDark,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _DetailBackdrop(
              imageUrl: backdropUrl,
              scale: scale,
              onBack: onBack,
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    0,
                    horizontal,
                    40 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 25 * scale,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                      SizedBox(height: 11 * scale),
                      _DetailMetadata(
                        year: year,
                        duration: duration,
                        rating: rating,
                        genres: genres,
                        scale: scale,
                      ),
                      SizedBox(height: 18 * scale),
                      _DetailPlayButton(
                        onTap: onPlay,
                        autofocus: playAutofocus,
                        scale: scale,
                      ),
                      if (actions.isNotEmpty) ...[
                        SizedBox(height: 16 * scale),
                        _DetailActions(actions: actions, scale: scale),
                      ],
                      if (plot?.trim().isNotEmpty == true) ...[
                        SizedBox(height: 21 * scale),
                        _ExpandablePlot(plot: plot!.trim(), scale: scale),
                      ],
                      _DetailFacts(
                        director: director,
                        writer: writer,
                        cast: cast,
                        plot: plot,
                        scale: scale,
                      ),
                      if (body != null) ...[
                        SizedBox(height: 28 * scale),
                        body!,
                      ],
                      if (similarItems.isNotEmpty) ...[
                        SizedBox(height: 30 * scale),
                        _SimilarSection(items: similarItems, scale: scale),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBackdrop extends StatelessWidget {
  final String? imageUrl;
  final double scale;
  final VoidCallback onBack;

  const _DetailBackdrop({
    required this.imageUrl,
    required this.scale,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final pixelWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(720, 1920);
    final hasImage = imageUrl?.trim().isNotEmpty == true;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.surfaceDark,
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: imageUrl!.trim(),
                    fit: BoxFit.cover,
                    memCacheWidth: pixelWidth,
                    fadeInDuration: const Duration(milliseconds: 180),
                    errorWidget: (_, _, _) => const _BackdropPlaceholder(),
                  )
                : const _BackdropPlaceholder(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x70000000),
                  Color(0x10000000),
                  Color(0xB0000000),
                  AppColors.primaryDark,
                ],
                stops: [0, 0.42, 0.78, 1],
              ),
            ),
          ),
          Positioned(
            top: 12 * scale,
            left: 12 * scale,
            child: TvFocusable(
              onTap: onBack,
              borderRadius: BorderRadius.circular(24 * scale),
              child: Container(
                width: 44 * scale,
                height: 44 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.66),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: 23 * scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropPlaceholder extends StatelessWidget {
  const _BackdropPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(
      Icons.movie_filter_rounded,
      color: AppColors.textMuted,
      size: 52,
    ),
  );
}

class _DetailMetadata extends StatelessWidget {
  final String? year;
  final String? duration;
  final String? rating;
  final List<String> genres;
  final double scale;

  const _DetailMetadata({
    required this.year,
    required this.duration,
    required this.rating,
    required this.genres,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    void addText(String? value, {Color color = AppColors.textSecondary}) {
      if (value?.trim().isNotEmpty != true) return;
      items.add(
        Text(
          value!.trim(),
          style: TextStyle(
            color: color,
            fontSize: 12.5 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    addText(year);
    addText(duration);
    if (rating?.trim().isNotEmpty == true) {
      addText('★ ${rating!.trim()}', color: AppColors.warning);
    }
    items.add(_MetaBadge(label: 'HD', scale: scale));
    for (final genre in genres) {
      items.add(_GenreChip(label: genre, scale: scale));
    }

    return Wrap(spacing: 9 * scale, runSpacing: 8 * scale, children: items);
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final double scale;

  const _MetaBadge({required this.label, required this.scale});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 2 * scale),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.textSecondary),
      borderRadius: BorderRadius.circular(4 * scale),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 10.5 * scale,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _GenreChip extends StatelessWidget {
  final String label;
  final double scale;

  const _GenreChip({required this.label, required this.scale});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9 * scale, vertical: 4 * scale),
    decoration: BoxDecoration(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(14 * scale),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11.5 * scale,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _DetailPlayButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool autofocus;
  final double scale;

  const _DetailPlayButton({
    required this.onTap,
    required this.autofocus,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) => TvFocusable(
    autofocus: autofocus,
    onTap: onTap,
    borderRadius: BorderRadius.circular(28 * scale),
    child: AnimatedOpacity(
      opacity: onTap == null ? 0.48 : 1,
      duration: const Duration(milliseconds: 160),
      child: Container(
        constraints: BoxConstraints(minHeight: 50 * scale),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(28 * scale),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 27 * scale,
            ),
            SizedBox(width: 7 * scale),
            Text(
              'Reproducir',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailActions extends StatelessWidget {
  final List<VodDetailAction> actions;
  final double scale;

  const _DetailActions({required this.actions, required this.scale});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: actions
        .map(
          (action) => Flexible(
            child: TvFocusable(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(12 * scale),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 8 * scale,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      action.icon,
                      color: action.selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      size: 25 * scale,
                    ),
                    SizedBox(height: 5 * scale),
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: action.selected
                            ? AppColors.accentLight
                            : AppColors.textSecondary,
                        fontSize: 11.5 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _ExpandablePlot extends StatefulWidget {
  final String plot;
  final double scale;

  const _ExpandablePlot({required this.plot, required this.scale});

  @override
  State<_ExpandablePlot> createState() => _ExpandablePlotState();
}

class _ExpandablePlotState extends State<_ExpandablePlot> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.plot,
        maxLines: _expanded ? null : 3,
        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textPrimary.withValues(alpha: 0.92),
          fontSize: 14 * widget.scale,
          height: 1.48,
        ),
      ),
      TvFocusable(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(6 * widget.scale),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6 * widget.scale),
          child: Text(
            _expanded ? 'Ver menos' : 'Ver más...',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 12 * widget.scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );
}

class _DetailFacts extends StatelessWidget {
  final String? director;
  final String? writer;
  final String? cast;
  final String? plot;
  final double scale;

  const _DetailFacts({
    required this.director,
    required this.writer,
    required this.cast,
    required this.plot,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[
      if (director?.trim().isNotEmpty == true) ('Director', director!.trim()),
      if (writer?.trim().isNotEmpty == true) ('Guionista', writer!.trim()),
      if (isDistinctDetailCast(cast, plot)) ('Actores', cast!.trim()),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: facts
            .map(
              (fact) => Padding(
                padding: EdgeInsets.only(bottom: 7 * scale),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${fact.$1}:  ',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: fact.$2,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5 * scale,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SimilarSection extends StatelessWidget {
  final List<VodSimilarItem> items;
  final double scale;

  const _SimilarSection({required this.items, required this.scale});

  @override
  Widget build(BuildContext context) {
    if (DeviceProfile.isTv(context)) return _buildTv(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
        SizedBox(height: 20 * scale),
        Text(
          'Más similares',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18 * scale,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 14 * scale),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 172 * scale,
            childAspectRatio: 0.58,
            crossAxisSpacing: 12 * scale,
            mainAxisSpacing: 15 * scale,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return TvFocusable(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(10 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10 * scale),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppColors.cardElevated,
                            child: item.imageUrl?.trim().isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: item.imageUrl!.trim(),
                                    fit: BoxFit.cover,
                                    memCacheWidth: 360,
                                    errorWidget: (_, _, _) =>
                                        _PosterPlaceholder(title: item.title),
                                  )
                                : _PosterPlaceholder(title: item.title),
                          ),
                          if (item.badge?.trim().isNotEmpty == true)
                            Positioned(
                              right: 6 * scale,
                              bottom: 6 * scale,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 7 * scale,
                                  vertical: 3 * scale,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.78),
                                  borderRadius: BorderRadius.circular(
                                    5 * scale,
                                  ),
                                ),
                                child: Text(
                                  item.badge!,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 9.5 * scale,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 7 * scale),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5 * scale,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTv(BuildContext context) => TvVodSimilarRow<VodSimilarItem>(
    items: items,
    scale: scale,
    titleOf: (item) => item.title,
    imageOf: (item) => item.imageUrl,
    badgeOf: (item) => item.badge,
    onTapOf: (item) => item.onTap,
  );
}

class _PosterPlaceholder extends StatelessWidget {
  final String title;

  const _PosterPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        title,
        maxLines: 4,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
