
enum ImageResolutionVariant {
  /// Resolución optimizada para posters verticales en tarjetas (~w342).
  poster,

  /// Resolución para miniaturas pequeñas y episodios (~w185 / ~w200).
  thumbnail,

  /// Resolución máxima para backdrops en carrusel Hero o cabeceras (~w780).
  heroBackdrop,

  /// Resolución para detalles o vistas a pantalla completa (~w1280 o superior).
  fullScreen,
}

/// Servicio centralizado para normalizar la resolución de URLs de imágenes
/// de catálogo (TMDB y similares), evitando descargar resoluciones masivas
/// (w1280 o original) en tarjetas pequeñas o listas del Home.
class ImageResolutionService {
  static final RegExp _tmdbRegex = RegExp(
    r'^(https?://image\.tmdb\.org/t/p/)([^/]+)(/.*)$',
    caseSensitive: false,
  );

  /// Normaliza la URL de una imagen para la variante solicitada.
  /// Si la URL no pertenece a TMDB o no tiene formato reconocible, se devuelve sin cambios.
  static String normalize(
    String? url, {
    ImageResolutionVariant variant = ImageResolutionVariant.poster,
  }) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();

    final match = _tmdbRegex.firstMatch(trimmed);
    if (match != null) {
      final prefix = match.group(1)!;
      final currentSize = match.group(2)!.toLowerCase();
      final path = match.group(3)!;

      final targetSize = switch (variant) {
        ImageResolutionVariant.poster => 'w342',
        ImageResolutionVariant.thumbnail => 'w185',
        ImageResolutionVariant.heroBackdrop => 'w780',
        ImageResolutionVariant.fullScreen =>
          (currentSize == 'original' ? 'w1280' : currentSize),
      };

      return '$prefix$targetSize$path';
    }

    return trimmed;
  }
}
