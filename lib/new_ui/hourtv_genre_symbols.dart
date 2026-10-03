import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../mobile_ui/hourtv_genre_service.dart';

String hourTvGenreSymbolKey(String value) {
  final key = HourTvGenreService.normalize(value);
  const aliases = {
    'infantil': 'familiar',
    'familia': 'familiar',
    'guerra': 'belica',
    'musica': 'musical',
    'horror': 'terror',
    'thriller': 'suspenso',
    'science fiction': 'ciencia ficcion',
  };
  return aliases[key] ?? key;
}

/// Hand-drawn silhouettes share one pearl-silver lighting/material treatment.
class HourTvGenreSymbol extends CustomPainter {
  HourTvGenreSymbol(this.genre, {this.bright = false});
  final String genre;
  final bool bright;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 24, size.height / 24);
    final metal = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          const Color(0xFFE8E6DF),
          bright ? Colors.white : const Color(0xFF969A9E),
          const Color(0xFFD4D5D2),
        ],
        stops: const [0, .35, .72, 1],
      ).createShader(const Rect.fromLTWH(0, 0, 24, 24));
    final dark = Paint()..color = const Color(0xFF181A1D);
    void shape(Path p) {
      c.drawShadow(p, Colors.black.withValues(alpha: .8), 1.8, false);
      c.drawPath(p, metal);
      c.drawPath(
        p,
        Paint()
          ..color = Colors.white.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .35,
      );
    }

    void oval(double x, double y, double w, double h) =>
        shape(Path()..addOval(Rect.fromLTWH(x, y, w, h)));
    void rect(double x, double y, double w, double h) => shape(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(.8),
        ),
      ),
    );
    Path polygon(List<double> xy) {
      final p = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        p.lineTo(xy[i], xy[i + 1]);
      }
      return p..close();
    }

    void line(double x, double y, double xx, double yy, {double width = 1.8}) =>
        c.drawLine(
          Offset(x, y),
          Offset(xx, yy),
          Paint()
            ..shader = metal.shader
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round,
        );
    void mask(bool smile, {bool horror = false}) {
      shape(
        Path()
          ..moveTo(4, 3)
          ..quadraticBezierTo(12, 0, 20, 3)
          ..quadraticBezierTo(21, 17, 12, 23)
          ..quadraticBezierTo(3, 17, 4, 3)
          ..close(),
      );
      c.drawOval(const Rect.fromLTWH(6, 7, 4, 4), dark);
      c.drawOval(const Rect.fromLTWH(14, 7, 4, 4), dark);
      if (horror) {
        c.drawOval(const Rect.fromLTWH(10, 13, 4, 8), dark);
      } else {
        c.drawPath(
          Path()
            ..moveTo(7, smile ? 14 : 18)
            ..quadraticBezierTo(12, smile ? 21 : 12, 17, smile ? 14 : 18),
          Paint()
            ..color = dark.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    switch (hourTvGenreSymbolKey(genre)) {
      case 'accion':
        final p = Path();
        for (var i = 0; i < 20; i++) {
          final a = i * math.pi / 10 - math.pi / 2;
          final r = i.isEven ? 11.0 : 5.0;
          final x = 12 + math.cos(a) * r, y = 12 + math.sin(a) * r;
          if (i == 0) {
            p.moveTo(x, y);
          } else {
            p.lineTo(x, y);
          }
        }
        shape(p..close());
        oval(9, 9, 6, 6);
      case 'aventura':
        shape(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addOval(const Rect.fromLTWH(2, 2, 20, 20))
            ..addOval(const Rect.fromLTWH(4, 4, 16, 16)),
        );
        shape(polygon([17, 6, 14, 14, 6, 18, 10, 10]));
      case 'animacion':
        rect(3, 9, 18, 12);
        shape(polygon([2, 4, 20, 1, 21, 6, 3, 9]));
        c.drawPath(polygon([10, 12, 16, 15, 10, 18]), dark);
        line(7, 4, 8, 7, width: 1);
        line(13, 3, 14, 6, width: 1);
      case 'comedia':
        mask(true);
      case 'drama':
        mask(false);
      case 'terror':
        mask(false, horror: true);
      case 'suspenso':
        shape(polygon([19, 1, 22, 4, 12, 15, 9, 12]));
        rect(4, 15, 7, 3);
        line(8, 11, 14, 17, width: 2);
        line(5, 19, 9, 15, width: 3);
      case 'ciencia ficcion':
        oval(5, 5, 14, 14);
        c.save();
        c.translate(12, 12);
        c.rotate(-.45);
        c.drawOval(
          const Rect.fromLTWH(-11, -3, 22, 6),
          Paint()
            ..shader = metal.shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7,
        );
        c.restore();
      case 'fantasia':
        shape(
          polygon([
            5,
            22,
            3,
            16,
            5,
            10,
            3,
            7,
            8,
            8,
            7,
            3,
            12,
            6,
            15,
            2,
            16,
            7,
            21,
            10,
            22,
            15,
            18,
            14,
            17,
            11,
            13,
            12,
            11,
            16,
            15,
            22,
          ]),
        );
        c.drawCircle(const Offset(16, 9), 1, dark);
      case 'crimen':
        shape(
          polygon([2, 6, 22, 6, 22, 11, 12, 11, 9, 22, 3, 22, 6, 11, 2, 11]),
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 12, 5, 5),
            const Radius.circular(2),
          ),
          Paint()
            ..shader = metal.shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case 'misterio':
        shape(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addOval(const Rect.fromLTWH(2, 2, 15, 15))
            ..addOval(const Rect.fromLTWH(4, 4, 11, 11)),
        );
        line(15, 15, 22, 22, width: 3);
      case 'documental':
        oval(3, 2, 8, 8);
        oval(12, 2, 8, 8);
        rect(3, 11, 14, 10);
        shape(polygon([18, 13, 23, 10, 23, 21, 18, 18]));
      case 'romance':
        shape(
          Path()
            ..moveTo(12, 22)
            ..cubicTo(-8, 8, 4, -3, 12, 6)
            ..cubicTo(20, -3, 32, 8, 12, 22)
            ..close(),
        );
      case 'familiar':
        oval(3, 2, 6, 6);
        oval(15, 2, 6, 6);
        oval(5, 3, 14, 12);
        oval(6, 13, 12, 10);
        oval(2, 14, 5, 7);
        oval(17, 14, 5, 7);
        oval(4, 19, 6, 5);
        oval(14, 19, 6, 5);
        c.drawCircle(const Offset(9, 8), 1, dark);
        c.drawCircle(const Offset(15, 8), 1, dark);
        c.drawOval(const Rect.fromLTWH(10, 10, 4, 3), dark);
      case 'belica':
        shape(
          Path()
            ..moveTo(3, 16)
            ..cubicTo(2, 0, 22, 0, 21, 16)
            ..close(),
        );
        rect(1, 16, 22, 3);
        line(6, 20, 10, 23, width: 1);
      case 'historia':
        shape(polygon([1, 7, 12, 1, 23, 7]));
        rect(2, 8, 20, 2);
        for (final x in [4.0, 10.0, 16.0]) {
          rect(x, 11, 3, 9);
        }
        rect(1, 21, 22, 2);
      case 'musical':
        shape(
          polygon([8, 3, 21, 1, 21, 18, 18, 18, 18, 6, 11, 8, 11, 21, 8, 21]),
        );
        oval(2, 17, 9, 6);
        oval(13, 14, 8, 6);
      case 'western':
        oval(1, 14, 22, 7);
        shape(
          Path()
            ..moveTo(5, 16)
            ..lineTo(7, 4)
            ..quadraticBezierTo(10, 1, 12, 5)
            ..quadraticBezierTo(17, 0, 19, 5)
            ..lineTo(20, 16)
            ..close(),
        );
        line(6, 14, 19, 14, width: 1);
      case 'policial':
        shape(
          polygon([5, 2, 12, 4, 19, 2, 22, 7, 20, 17, 12, 23, 4, 17, 2, 7]),
        );
        c.drawPath(
          polygon([
            12,
            7,
            14,
            11,
            18,
            11,
            15,
            14,
            16,
            18,
            12,
            16,
            8,
            18,
            9,
            14,
            6,
            11,
            10,
            11,
          ]),
          dark,
        );
      case 'biografia':
        oval(7, 1, 10, 13);
        shape(
          Path()
            ..moveTo(2, 23)
            ..quadraticBezierTo(2, 14, 12, 14)
            ..quadraticBezierTo(22, 14, 22, 23)
            ..close(),
        );
      case 'deportes':
        shape(
          Path()
            ..moveTo(6, 2)
            ..lineTo(18, 2)
            ..quadraticBezierTo(19, 15, 12, 16)
            ..quadraticBezierTo(5, 15, 6, 2)
            ..close(),
        );
        line(12, 16, 12, 21, width: 3);
        rect(6, 21, 12, 2);
        c.drawPath(
          Path()
            ..moveTo(5, 5)
            ..lineTo(2, 5)
            ..quadraticBezierTo(1, 13, 7, 13),
          Paint()
            ..shader = metal.shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        c.drawPath(
          Path()
            ..moveTo(19, 5)
            ..lineTo(22, 5)
            ..quadraticBezierTo(23, 13, 17, 13),
          Paint()
            ..shader = metal.shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case 'noticias':
        rect(2, 2, 20, 21);
        c.drawRect(const Rect.fromLTWH(5, 5, 14, 4), dark);
        c.drawRect(const Rect.fromLTWH(5, 12, 6, 7), dark);
        for (final y in [12.0, 15.0, 18.0]) {
          c.drawLine(
            Offset(13, y),
            Offset(19, y),
            Paint()
              ..color = dark.color
              ..strokeWidth = 1,
          );
        }
      default:
        rect(3, 5, 18, 15);
        line(4, 9, 20, 9);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(HourTvGenreSymbol old) =>
      old.genre != genre || old.bright != bright;
}
