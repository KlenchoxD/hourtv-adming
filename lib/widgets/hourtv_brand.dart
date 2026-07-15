import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Representación nativa del SVG assets/branding/hourtv_icon.svg.
///
/// Mantiene el arco rojo abierto y el play blanco sin cargar una dependencia
/// de SVG en tiempo de ejecución.
class HourTvLogo extends StatelessWidget {
  final double size;

  const HourTvLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'HourTV',
      child: CustomPaint(
        size: Size.square(size),
        painter: const _HourTvLogoPainter(),
      ),
    );
  }
}

class HourTvWordmark extends StatelessWidget {
  final double fontSize;

  const HourTvWordmark({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Hour'),
          const TextSpan(
            text: 'TV',
            style: TextStyle(color: AppColors.accent),
          ),
        ],
      ),
      maxLines: 1,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
    );
  }
}

class _HourTvLogoPainter extends CustomPainter {
  const _HourTvLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final arcPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * (46 / 512)
      ..strokeCap = StrokeCap.round;
    final arcRect = Rect.fromCircle(center: center, radius: side * (196 / 512));
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 7 / 4, false, arcPaint);

    final play = Path()
      ..moveTo(center.dx - side * (52 / 512), center.dy - side * (84 / 512))
      ..lineTo(center.dx + side * (104 / 512), center.dy)
      ..lineTo(center.dx - side * (52 / 512), center.dy + side * (84 / 512))
      ..close();
    canvas.drawPath(play, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _HourTvLogoPainter oldDelegate) => false;
}
