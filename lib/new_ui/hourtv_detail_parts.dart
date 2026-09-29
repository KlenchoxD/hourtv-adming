import 'package:flutter/material.dart';

import '../mobile_ui/hourtv_mobile_components.dart';
import '../models/channel.dart';
import '../services/cast_service.dart';
import '../services/image_resolution_service.dart';
import '../services/remote_playback.dart';
import '../services/storage_service.dart';
import '../services/subtitles/github_subtitle_repository.dart';
import 'hourtv_cast_controls_screen.dart';
import 'hourtv_cast_sheet.dart';

// Piezas de la ficha que comparten películas y series, para que las dos se
// vean igual (antes cada una tenía su propio diseño).

const _black = Color(0xFF000000);
const _surface = Color(0xFF101412);
const _surfaceControl = Color(0xFF151917);
const _line = Color(0xFF27302C);
const _muted = Color(0xFFA6A6B0);
const _accent = Color(0xFF00C781);

/// "133 Min" -> "2 h 13 min". Si el texto no trae minutos reconocibles se
/// devuelve tal cual: es preferible mostrar el dato original que inventar.
String? hourTvPrettyDuration(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final match = RegExp(
    r'^(\d+)\s*(min|m|minutos?)?\.?$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return value;
  final total = int.tryParse(match.group(1)!);
  if (total == null || total <= 0) return value;
  final hours = total ~/ 60;
  final minutes = total % 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes min';
}

/// "2005-09-16" -> "16 de septiembre de 2005"; tal cual si no es fecha.
String? hourTvPrettyDate(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final date = value.length >= 10 ? DateTime.tryParse(value) : null;
  if (date == null) return value;
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${date.day} de ${months[date.month - 1]} de ${date.year}';
}

/// Cabecera del teléfono: imagen a todo el ancho con degradado, póster
/// chico y, a su lado, el título y los datos (★ año duración).
class HourTvDetailPhoneHeader extends StatelessWidget {
  const HourTvDetailPhoneHeader({
    super.key,
    required this.title,
    required this.meta,
    this.backdropUrl,
    this.posterUrl,
    this.poster,
  });

  final String title;
  final Widget meta;

  /// Imagen horizontal; sin ella se usa el póster recortado arriba.
  final String? backdropUrl;
  final String? posterUrl;

  /// Póster ya armado (p. ej. con animación Hero); si no, se usa [posterUrl].
  final Widget? poster;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).height;
    final height = (screen * .42).clamp(280.0, 380.0);
    final hasBackdrop = backdropUrl?.trim().isNotEmpty ?? false;
    final imageUrl = hasBackdrop ? backdropUrl : posterUrl;
    final posterWidget =
        poster ??
        (posterUrl?.trim().isNotEmpty ?? false
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 108,
                  child: HourTvArtwork(
                    url: posterUrl,
                    memCacheWidth: 216,
                    memCacheHeight: 324,
                  ),
                ),
              )
            : null);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl == null || imageUrl.trim().isEmpty)
            const ColoredBox(color: _surface)
          else
            // topCenter sin banner: el póster vertical recortado al centro
            // corta justo la cara del protagonista.
            // HourTvArtwork también muestra imágenes sin CORS en web.
            HourTvArtwork(
              url: imageUrl,
              memCacheWidth: 900,
              // Solo el ancho: con los dos, un póster vertical se deformaría.
              memCacheHeight: null,
              variant: hasBackdrop
                  ? ImageResolutionVariant.heroBackdrop
                  : ImageResolutionVariant.poster,
              alignment: hasBackdrop ? Alignment.center : Alignment.topCenter,
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x66000000), _black],
                stops: [.42, .74, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x73000000),
                  Color(0x00000000),
                  Color(0x73000000),
                ],
                stops: [0, .32, 1],
              ),
            ),
          ),
          const HourTvDetailBackButton(left: 12, top: 8),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (posterWidget != null) ...[
                  posterWidget,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.8,
                          shadows: [
                            Shadow(
                              color: Color(0xCC000000),
                              blurRadius: 12,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      meta,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón atrás sobre la imagen (va dentro de un Stack).
class HourTvDetailBackButton extends StatelessWidget {
  const HourTvDetailBackButton({
    super.key,
    required this.left,
    required this.top,
    this.close = false,
  });
  final double left;
  final double top;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).top;
    return Positioned(
      left: left,
      // En modo inmersivo el inset baja a 0 pero las barras reaparecen con un
      // gesto: sin un mínimo, el botón quedaría encima del reloj.
      top: top + (inset > 12 ? inset + 10 : 26),
      child: Tooltip(
        message: close ? 'Cerrar' : 'Volver',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                close ? Icons.close_rounded : Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ★ puntuación • año • duración (o "2 temporadas"). Solo datos reales.
class HourTvDetailMeta extends StatelessWidget {
  const HourTvDetailMeta({super.key, this.rating, this.year, this.extra});
  final String? rating;
  final String? year;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final rating = this.rating?.trim();
    final year = this.year?.trim();
    final extra = this.extra?.trim();
    Widget text(String value) => Text(
      value,
      style: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
    );
    final parts = <Widget>[
      if (rating != null && rating.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF5C518), size: 16),
            const SizedBox(width: 3),
            Text(
              rating,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      if (year != null && year.isNotEmpty) text(year),
      if (extra != null && extra.isNotEmpty) text(extra),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 9,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const Text('•', style: TextStyle(color: _muted)),
          parts[i],
        ],
      ],
    );
  }
}

/// Favorito · Me gusta · Transmitir, en tres cajas del mismo ancho.
class HourTvDetailActionBoxes extends StatelessWidget {
  const HourTvDetailActionBoxes({
    super.key,
    required this.inList,
    required this.onList,
    required this.liked,
    required this.likeLabel,
    required this.onLike,
    this.onCast,
  });

  final bool inList;
  final VoidCallback onList;
  final bool liked;
  final String likeLabel;
  final VoidCallback onLike;

  /// null = sin caja "Transmitir" (en el navegador no hay Chromecast/DLNA).
  final VoidCallback? onCast;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RemotePlayback?>(
      valueListenable: RemotePlayback.active,
      builder: (context, casting, _) => Row(
        children: [
          Expanded(
            child: _box(
              inList ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              'Favorito',
              onList,
              active: inList,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _box(
              Icons.thumb_up_alt_rounded,
              likeLabel,
              onLike,
              active: liked,
            ),
          ),
          if (onCast case final onCast?) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _box(
                casting != null
                    ? Icons.cast_connected_rounded
                    : Icons.cast_rounded,
                casting != null ? 'Conectado' : 'Transmitir',
                onCast,
                active: casting != null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _box(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: _surfaceControl,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? _accent : const Color(0xFFF5F5F5),
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF5F5F5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// SINOPSIS y, debajo, la ficha en dos columnas. Un dato que no existe no se
/// muestra (nada de "No disponible").
class HourTvDetailInfo extends StatelessWidget {
  const HourTvDetailInfo({
    super.key,
    this.plot,
    this.director,
    this.writer,
    this.genre,
    this.releaseDate,
    this.year,
    this.rating,
    this.duration,
    this.durationLabel = 'Duración',
  });

  final String? plot;
  final String? director;
  final String? writer;
  final String? genre;
  final String? releaseDate;
  final String? year;
  final String? rating;
  final String? duration;

  /// "Duración" en películas, "Temporadas" en series.
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    final plot = clean(this.plot);
    final rating = clean(this.rating);
    final cells = <(String, String)>[
      if (clean(director) case final v?) ('Dirección', v),
      if (clean(writer) case final v?) ('Guion', v),
      if (clean(genre) case final v?) ('Género', v),
      if (hourTvPrettyDate(releaseDate) case final v?) ('Estreno', v),
      if (clean(year) case final v?) ('Año', v),
      if (rating != null) ('Puntuación', '$rating / 10'),
      if (clean(duration) case final v?) (durationLabel, v),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plot != null) ...[
          const Text(
            'SINOPSIS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plot,
            style: const TextStyle(
              color: Color(0xFFC4C8C6),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ],
        if (cells.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: plot == null ? 0 : 16),
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xB327302C))),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (final (label, value) in cells)
                      SizedBox(
                        // El género suele ser largo: ocupa toda la fila.
                        width: label == 'Género'
                            ? constraints.maxWidth
                            : cellWidth,
                        child: _cell(label, value),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  static Widget _cell(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF7D8581),
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFFF5F5F5),
          height: 1.25,
        ),
      ),
    ],
  );
}

/// Abre "Transmitir a TV" para [channel] (una película o un episodio) y,
/// si se conecta, los controles remotos.
Future<void> hourTvCastChannel(
  BuildContext context,
  Channel channel, {
  String? title,
}) async {
  final name = title ?? channel.displayName;
  final playback = await showCastSheet(
    context,
    title: name,
    media: () => CastService.resolveMedia(channel),
    posterUrl: channel.backdrop ?? channel.logo,
    mediaType: channel.type,
    subtitle: () async =>
        (await GithubSubtitleRepository().findFor(channel)).firstOrNull,
    // Como en el reproductor: visibles de entrada solo si se eligió
    // "Siempre en español" (el idioma del audio aún no se conoce).
    subtitleOn: const {'always', 'manual'}.contains(
      StorageService.getSetting('preferredSubtitleMode', defaultValue: 'auto'),
    ),
  );
  if (!context.mounted || playback == null) return;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => CastControlsScreen(title: name, playback: playback),
    ),
  );
}

/// Portada pequeña junto al título en la ficha de computador/tablet, como la
/// del celular. Sin portada no ocupa espacio.
Widget hourTvWideHeroWithPoster({
  required String? posterUrl,
  required Widget info,
  double width = 150,
}) {
  final url = posterUrl?.trim();
  if (url == null || url.isEmpty) return info;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Container(
        width: width,
        height: width * 1.5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), blurRadius: 24),
          ],
        ),
        child: HourTvArtwork(
          url: url,
          borderRadius: BorderRadius.circular(10),
          memCacheWidth: (width * 2).round(),
          memCacheHeight: (width * 3).round(),
        ),
      ),
      const SizedBox(width: 24),
      Flexible(child: info),
    ],
  );
}
