import 'package:flutter/material.dart';

/// Composición del destacado web, independiente del banner móvil.
class HourTvWebHero extends StatelessWidget {
  const HourTvWebHero({
    super.key,
    required this.backdrop,
    required this.content,
  });
  final Widget backdrop;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 1000 ? 32.0 : 60.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        backdrop,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xA6050505), Color(0x38050505), Color(0x00050505)],
              stops: [0, 0.45, 0.85],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x18050505), Color(0x40050505), Color(0xFF050505)],
              stops: [0, 0.65, 1],
            ),
          ),
        ),
        Positioned(
          left: padding,
          bottom: 112,
          child: SizedBox(
            width: (width - padding * 2).clamp(0.0, 520.0),
            child: content,
          ),
        ),
      ],
    );
  }
}
