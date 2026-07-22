import 'package:flutter/material.dart';

/// Logotipo final de HourTV utilizado en todos los dispositivos.
class HourTvLogo extends StatelessWidget {
  final double size;
  final double? width;

  const HourTvLogo({super.key, required this.size, this.width});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'HourTV',
      child: SizedBox(
        height: size,
        width: width ?? size * 1.55,
        child: Image.asset(
          'assets/branding/hourtv_logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Conservado temporalmente para compatibilidad con pantallas antiguas.
/// El logotipo final ya contiene el nombre completo.
@Deprecated('Usa HourTvLogo; el logo final ya incluye el nombre.')
class HourTvWordmark extends StatelessWidget {
  final double fontSize;

  const HourTvWordmark({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
