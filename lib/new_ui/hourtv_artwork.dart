import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen de catalogo con ajuste adaptable.
///
/// El catalogo no es homogeneo: unos titulos traen poster vertical y otros
/// traen un fotograma apaisado en el mismo campo. En una celda vertical,
/// `contain` deja media tarjeta vacia cuando la imagen es apaisada, y `cover`
/// recorta el arte cuando si es un poster.
///
/// Con [adaptive] se mide la imagen real (sin descarga extra: usa el mismo
/// provider y cache que la pinta) y solo si resulta apaisada se pasa a
/// `cover`. Los posters siguen viendose completos.
class AdaptiveArtwork extends StatefulWidget {
  const AdaptiveArtwork({
    super.key,
    required this.url,
    required this.fit,
    required this.fallback,
    this.cacheWidth = 260,
    this.alignment = Alignment.center,
    this.adaptive = false,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;

  /// Widget que se pinta mientras carga, si no hay url o si falla.
  final Widget fallback;

  /// Ancho de decodificacion: las imagenes se cachean/decodifican a esta
  /// resolucion en vez de la original. Clave para el rendimiento en TV Box
  /// arm32 (evita saturar memoria/GPU con caratulas a tamano completo).
  final int cacheWidth;

  /// Activar solo en celdas verticales. En celdas apaisadas `cover` ya es lo
  /// correcto y medir no aporta nada.
  final bool adaptive;

  @override
  State<AdaptiveArtwork> createState() => _AdaptiveArtworkState();
}

class _AdaptiveArtworkState extends State<AdaptiveArtwork> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _wide = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  @override
  void didUpdateWidget(AdaptiveArtwork old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.adaptive != widget.adaptive) {
      _wide = false;
      _measure();
    }
  }

  void _measure() {
    _drop();
    final url = widget.url;
    if (!widget.adaptive || url == null || url.trim().isEmpty) return;
    final stream = CachedNetworkImageProvider(
      url,
      maxWidth: widget.cacheWidth,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final wide = info.image.width > info.image.height;
      if (mounted && wide != _wide) setState(() => _wide = wide);
    }, onError: (_, _) {});
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _drop() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || url.trim().isEmpty) return widget.fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: _wide ? BoxFit.cover : widget.fit,
      alignment: widget.alignment,
      memCacheWidth: widget.cacheWidth,
      width: double.infinity,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => widget.fallback,
      errorWidget: (_, _, _) => widget.fallback,
    );
  }
}
