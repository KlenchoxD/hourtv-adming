import 'package:flutter/material.dart';
import 'hourtv_web_feedback.dart';

/// Botones de reproducir estilo Netflix, iguales en toda la app: el
/// principal blanco con letra negra y el secundario gris translúcido.
/// Antes era una píldora verde con letra negra y sombra, que se veía pesada.
class HourTvPlayButton extends StatelessWidget {
  const HourTvPlayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.secondary = false,
    this.large = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  /// Gris translúcido ("Desde el inicio", "Mi lista").
  final bool secondary;

  /// Tamaño para tablet/TV/computador; en teléfono va compacto como Netflix.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final height = large ? 52.0 : 44.0;
    return HourTvWebFeedback(
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? const Color(0xB36D6D6E) : Colors.white,
          foregroundColor: secondary ? Colors.white : Colors.black,
          disabledBackgroundColor: Colors.white24,
          minimumSize: Size(large ? 150 : 0, height),
          padding: EdgeInsets.symmetric(horizontal: large ? 26 : 18),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        icon: Icon(
          icon,
          size: secondary ? (large ? 24 : 22) : (large ? 32 : 28),
        ),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: large ? 18 : 16,
              fontWeight: secondary ? FontWeight.w600 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de avance bajo "Continuar", con el tiempo que falta.
class HourTvResumeProgress extends StatelessWidget {
  const HourTvResumeProgress({
    super.key,
    required this.fraction,
    required this.label,
  });

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 3,
              color: const Color(0xFF00C781),
              backgroundColor: Colors.white24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFC4C8C6), fontSize: 12.5),
        ),
      ],
    );
  }
}
