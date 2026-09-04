import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/device_type.dart';
import 'hourtv_focusable.dart';

// Mismos tokens que el resto del diseño nuevo (hourtv_new_shell.dart /
// hourtv_profile_page.dart): nada de Scaffold+AppBar de Material por
// defecto, todo con estos colores y TvFocusable para que el control
// remoto muestre foco real (borde rojo), no un InkWell mudo.
const kSetRed = Color(0xFF00C781);
const kSetBlack = Color(0xFF050505);
const kSetSurface = Color(0xFF101412);
const kSetLine = Color(0xFF27302C);
const kSetMuted = Color(0xFFA6A6B0);

/// Estructura comun de toda pantalla de ajustes dentro de Perfil: fondo
/// negro, boton de volver + titulo en Inter (como el resto del diseño
/// nuevo), y una lista con los ajustes.
class HourTvSettingsScaffold extends StatelessWidget {
  const HourTvSettingsScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSetBlack,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _BackButton(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.robotoSerif(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              letterSpacing: -.6,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: const TextStyle(color: kSetMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: () => Navigator.of(context).maybePop(),
      decorated: false,
      scale: 1.06,
      borderRadius: BorderRadius.circular(12),
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kSetSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? kSetRed : kSetLine,
            width: _focused ? 2 : 1,
          ),
        ),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
    );
  }
}

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: kSetMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
  );
}

/// Fila base tocable, foco real de D-pad (borde rojo + escala), usada por
/// toggle/choice/radio. Toda la fila es el objetivo de foco (como
/// _MediaCard/_RailItem en el resto de la app), nunca un widget interactivo
/// anidado dentro.
class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    required this.onTap,
    this.autofocus = false,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final bool autofocus;
  final bool highlighted;

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // El borde rojo es SOLO del foco literal del D-pad (un unico resalte que
    // se mueve). "highlighted" (seleccionado/activado) se muestra en el
    // icono/switch, nunca en el borde -> nunca dos filas rojas a la vez.
    // El foco automatico solo tiene sentido en TV (control remoto sin
    // puntero): en telefono/tablet/desktop mostraba el anillo rojo de foco
    // sobre la primera fila apenas se abria la pantalla, sin que el usuario
    // hubiera tocado nada -> parecia una fila "activada sola", sobre todo
    // en pantallas con un solo control (Control parental).
    final effectiveAutofocus = widget.autofocus && DeviceProfile.isTv(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TvFocusable(
        autofocus: effectiveAutofocus,
        onTap: widget.onTap,
        decorated: false,
        scale: 1.015,
        borderRadius: BorderRadius.circular(16),
        onFocusChange: (value) => setState(() => _focused = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: kSetSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused ? kSetRed : kSetLine,
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.highlighted ? kSetRed : Colors.white,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(color: kSetMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              widget.trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.autofocus = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => _SettingsRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    autofocus: autofocus,
    highlighted: value,
    onTap: () => onChanged(!value),
    trailing: IgnorePointer(
      child: Switch(
        value: value,
        onChanged: (_) {},
        activeThumbColor: Colors.white,
        activeTrackColor: kSetRed,
      ),
    ),
  );
}

class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.autofocus = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => _SettingsRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    autofocus: autofocus,
    onTap: onTap,
    trailing: const Icon(Icons.chevron_right_rounded, color: kSetMuted),
  );
}

class SettingsRadioRow extends StatelessWidget {
  const SettingsRadioRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
    this.checkbox = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;
  final bool checkbox;

  @override
  Widget build(BuildContext context) => _SettingsRow(
    icon: checkbox
        ? (selected
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded)
        : (selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded),
    title: title,
    subtitle: subtitle,
    autofocus: autofocus,
    highlighted: selected,
    onTap: onTap,
    trailing: const SizedBox.shrink(),
  );
}

class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.loading = false,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: kSetSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kSetLine),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: kSetRed,
                ),
              )
            else
              Icon(icon, color: iconColor ?? Colors.white, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: kSetMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boton de accion principal (rojo, ancho completo) con foco real de TV,
/// como el resto de botones destacados del diseño nuevo.
class SettingsActionButton extends StatefulWidget {
  const SettingsActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<SettingsActionButton> createState() => _SettingsActionButtonState();
}

class _SettingsActionButtonState extends State<SettingsActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: widget.autofocus && DeviceProfile.isTv(context),
      onTap: widget.onTap,
      decorated: false,
      scale: 1.03,
      borderRadius: BorderRadius.circular(14),
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 54,
        decoration: BoxDecoration(
          color: kSetRed,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
