import 'package:flutter/material.dart';

import '../storage_service.dart';

/// Apariencia de los subtítulos elegida en Perfil → Idioma y subtítulos. La
/// usan el reproductor y la vista previa de ajustes, así se ven iguales.
class SubtitleStyle {
  const SubtitleStyle({
    this.scale = 1.0,
    this.bold = false,
    this.color = 'white',
    this.background = 'box',
  });

  final double scale;
  final bool bold;

  /// 'white' | 'yellow' | 'green'.
  final String color;

  /// 'box' (caja semitransparente) | 'solid' (caja negra) | 'outline' (sin
  /// caja, con contorno como en el cine).
  final String background;

  static const colors = <(String, String, Color)>[
    ('white', 'Blanco', Colors.white),
    ('yellow', 'Amarillo', Color(0xFFFFE14D)),
    ('green', 'Verde claro', Color(0xFF7CF0B4)),
  ];

  static const backgrounds = <(String, String)>[
    ('box', 'Caja semitransparente'),
    ('solid', 'Caja negra'),
    ('outline', 'Sin caja, con contorno'),
  ];

  static SubtitleStyle load() => SubtitleStyle(
    scale:
        double.tryParse(
          '${StorageService.getSetting('subtitleFontScale', defaultValue: 1.0)}',
        ) ??
        1.0,
    bold: StorageService.getSetting('subtitleBold', defaultValue: false) == true,
    color: '${StorageService.getSetting('subtitleColor', defaultValue: 'white')}',
    background:
        '${StorageService.getSetting('subtitleBackground', defaultValue: 'box')}',
  );

  Color get textColor => colors
      .firstWhere((c) => c.$1 == color, orElse: () => colors.first)
      .$3;

  /// El subtítulo ya armado (texto + fondo), para superponer al video.
  Widget build(String text, {double baseSize = 18}) {
    final outline = background == 'outline';
    final label = Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: textColor,
        fontSize: baseSize * scale,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
        height: 1.3,
        // Sin caja, el contorno oscuro lo hace legible sobre fondos claros.
        shadows: outline
            ? const [
                Shadow(blurRadius: 3, color: Colors.black),
                Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
              ]
            : null,
      ),
    );
    if (outline) return label;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: background == 'solid' ? 1 : .66),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: label,
      ),
    );
  }
}
