import 'package:flutter/material.dart';

import '../mobile_ui/hourtv_mobile_components.dart';
import '../services/auth/auth_controller.dart';

/// Piezas visuales compartidas por Iniciar sesión, Contraseña nueva y Cuenta.

const hourTvAuthBg = Color(0xFF050505);
const hourTvAuthSurface = Color(0xFF131316);
const hourTvAuthLine = Color(0xFF2A2A30);
const hourTvAuthMuted = Color(0xFFA6A6B0);
const hourTvAuthEmerald = Color(0xFF00C781);
const hourTvAuthError = Color(0xFFFF6B6B);

/// Da acceso al [AuthController] de la sesión desde cualquier pantalla
/// (p. ej. Perfil > Cuenta), sin pasarlo de mano en mano.
class HourTvAuthScope extends InheritedNotifier<AuthController> {
  const HourTvAuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Sesión de la app en curso. Las pantallas abiertas con
  /// Navigator.push (Perfil > Cuenta) quedan por encima de la puerta de
  /// sesión y no la tienen como ancestro: la usan desde aquí.
  static AuthController? current;

  static AuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HourTvAuthScope>()?.notifier ??
      current;
}

/// Cabecera de marca: muro de pósters inclinado que se funde en negro, con
/// el logo y el lema encima. Le da identidad a la entrada (antes era un
/// formulario gris suelto en el centro).
class HourTvAuthHero extends StatelessWidget {
  const HourTvAuthHero({
    super.key,
    required this.height,
    this.tagline = 'Películas, series y TV en vivo. Gratis.',
  });

  final double height;
  final String? tagline;

  static const _posters = [
    'poster-eclipse',
    'poster-frontera',
    'poster-herencia',
    'poster-renacer',
    'poster-nacion-sin-ley',
    'poster-sombras-del-pasado',
    'poster-tiempo-fracturado',
    'poster-ultima-llamada',
    'poster-penitenciaria',
    'poster-cronicas-de-hierro',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.rotate(
                angle: -0.14,
                child: Opacity(
                  opacity: .5,
                  // Más ancho que cualquier pantalla (tablet, TV): tras girarlo
                  // no deben verse bordes vacíos.
                  child: SizedBox(
                    width: 1400,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < 44; i++)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/figma/phase-3-1/${_posters[i % _posters.length]}.png',
                              width: 112,
                              height: 168,
                              cacheWidth: 224,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99050505), Color(0x33050505), hourTvAuthBg],
                stops: [0, .45, 1],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, .72),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HourTvLogo(fontSize: 38),
                if (tagline != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    tagline!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de texto de la entrada: alto, redondeado y con su ícono.
class HourTvAuthField extends StatelessWidget {
  const HourTvAuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.toggleKey,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final Key? toggleKey;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: hourTvAuthMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: hourTvAuthEmerald),
        prefixIcon: Icon(icon, color: hourTvAuthMuted, size: 21),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                key: toggleKey,
                tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: hourTvAuthMuted,
                  size: 21,
                ),
              ),
        filled: true,
        fillColor: hourTvAuthSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border(hourTvAuthLine),
        enabledBorder: border(hourTvAuthLine),
        focusedBorder: border(hourTvAuthEmerald, 1.6),
      ),
    );
  }
}

/// Botón principal verde, ancho completo.
class HourTvAuthButton extends StatelessWidget {
  const HourTvAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: hourTvAuthEmerald,
          foregroundColor: Colors.black,
          disabledBackgroundColor: hourTvAuthEmerald.withValues(alpha: .35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.black,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Aviso de error o de éxito sobre el formulario.
class HourTvAuthMessage extends StatelessWidget {
  const HourTvAuthMessage({super.key, required this.text, this.error = true});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? hourTvAuthError : hourTvAuthEmerald;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
