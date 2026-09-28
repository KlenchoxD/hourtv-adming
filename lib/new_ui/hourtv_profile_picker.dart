import 'package:flutter/material.dart';

import '../mobile_ui/hourtv_mobile_components.dart';
import 'hourtv_profile_avatar.dart';
import 'hourtv_profile_avatars.dart';

const _muted = Color(0xFFA6A6B0);
const _line = Color(0xFF3A3A42);
const _emerald = Color(0xFF00C781);

/// Un perfil tal como se muestra en "¿Quién está viendo?".
class HourTvProfilePickerItem {
  const HourTvProfilePickerItem({
    required this.name,
    required this.avatarSeed,
    required this.isKids,
    required this.onTap,
  });

  final String name;
  final String avatarSeed;
  final bool isKids;
  final VoidCallback onTap;
}

/// Selector de perfil a pantalla completa, estilo Netflix: logo arriba,
/// avatares grandes sin caja y todo centrado en la pantalla. Lo usan el
/// selector local y el de cuenta en la nube para que se vean iguales.
class HourTvProfilePicker extends StatelessWidget {
  const HourTvProfilePicker({
    super.key,
    required this.profiles,
    this.onAdd,
    this.busy = false,
    this.header,
    this.footer = const [],
  });

  final List<HourTvProfilePickerItem> profiles;

  /// null = no se pueden agregar más perfiles.
  final VoidCallback? onAdd;
  final bool busy;

  /// Aviso opcional sobre la grilla (p. ej. importar datos de invitado).
  final Widget? header;
  final List<Widget> footer;

  static const _tileWidth = 132.0;
  static const _avatarRadius = 58.0;

  @override
  Widget build(BuildContext context) {
    // Todo en un solo bloque centrado: con el logo anclado arriba y la
    // grilla centrada aparte quedaban dos huecos grandes en la pantalla.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HourTvLogo(fontSize: 22),
                  const SizedBox(height: 28),
                  const Text(
                    '¿Quién está viendo?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (header != null) ...[header!, const SizedBox(height: 24)],
                  Wrap(
                    spacing: 16,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final profile in profiles)
                        _ProfileTile(
                          width: _tileWidth,
                          radius: _avatarRadius,
                          profile: profile,
                          enabled: !busy,
                        ),
                      if (onAdd != null)
                        _AddTile(
                          width: _tileWidth,
                          radius: _avatarRadius,
                          onTap: busy ? null : onAdd,
                        ),
                    ],
                  ),
                  ...footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.width,
    required this.radius,
    required this.profile,
    required this.enabled,
  });

  final double width;
  final double radius;
  final HourTvProfilePickerItem profile;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: InkWell(
          onTap: enabled ? profile.onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AvatarCircle(
                  seed: profile.avatarSeed,
                  name: profile.name,
                  radius: radius,
                  ringColor: profile.isKids ? _emerald : _line,
                ),
                const SizedBox(height: 10),
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (profile.isKids) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _emerald.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Infantil',
                      style: TextStyle(
                        color: _emerald,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.width, required this.radius, this.onTap});

  final double width;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Opacity(
        opacity: onTap == null ? .5 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _line, width: 2),
                  ),
                  child: const Icon(Icons.add_rounded, color: _muted, size: 40),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Agregar perfil',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Crear perfil ──────────────────────────────────────────────────────────
// Mismo lenguaje que "¿Quién está viendo?": bloque centrado, títulos sin
// mayúsculas forzadas y avatares en círculo. Compartido por el selector local
// y el de la nube.

/// Paso del asistente: flecha atrás arriba y el contenido centrado.
class HourTvProfileStep extends StatelessWidget {
  const HourTvProfileStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 80),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onBack != null)
          Positioned(
            left: 4,
            top: 4,
            child: IconButton(
              tooltip: 'Atrás',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/// Elegir entre perfil normal e infantil: dos tarjetas anchas, una debajo
/// de la otra, en vez de dos cuadritos que dejaban media pantalla vacía.
class HourTvProfileTypeChoice extends StatelessWidget {
  const HourTvProfileTypeChoice({super.key, required this.onPick});

  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TypeCard(
          icon: Icons.person_rounded,
          title: 'Perfil normal',
          description: 'Todo el catálogo: películas, series y TV en vivo',
          accent: Colors.white,
          onTap: () => onPick(false),
        ),
        const SizedBox(height: 14),
        _TypeCard(
          icon: Icons.child_care_rounded,
          title: 'Perfil infantil',
          description: 'Solo caricaturas y contenido para niños',
          accent: _emerald,
          onTap: () => onPick(true),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF131316),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: .12),
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grilla de avatares en círculo, sin etiquetas (antes decían "Hombre 1"
/// aunque la caricatura no lo fuera). Cada uno lleva la clave
/// `avatar-<id>` para las pruebas.
class HourTvAvatarGrid extends StatelessWidget {
  const HourTvAvatarGrid({
    super.key,
    required this.options,
    required this.onPick,
    this.kids = false,
    this.enabled = true,
  });

  final List<HourTvAvatarOption> options;
  final ValueChanged<String> onPick;
  final bool kids;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Ancho de 3 avatares: 6 opciones quedan 3 + 3 (no 4 + 2).
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 3 * 100 + 2 * 18 + 1),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        alignment: WrapAlignment.center,
        children: [
          for (final option in options)
            Semantics(
              button: true,
              label: option.label,
              child: InkWell(
                key: ValueKey('avatar-${option.id}'),
                onTap: enabled ? () => onPick(option.id) : null,
                customBorder: const CircleBorder(),
                child: _AvatarCircle(
                  seed: option.seed,
                  name: option.label,
                  radius: 50,
                  ringColor: kids ? _emerald : _line,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Avatar grande, campo de nombre y botón.
class HourTvProfileNameForm extends StatelessWidget {
  const HourTvProfileNameForm({
    super.key,
    required this.avatarSeed,
    required this.controller,
    required this.buttonLabel,
    required this.onSubmit,
    required this.onChanged,
    this.kids = false,
    this.busy = false,
  });

  final String? avatarSeed;
  final TextEditingController controller;
  final String buttonLabel;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;
  final bool kids;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final canSubmit = !busy && controller.text.trim().isNotEmpty;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      children: [
        if (avatarSeed != null)
          _AvatarCircle(
            seed: avatarSeed!,
            name: controller.text,
            radius: 64,
            ringColor: kids ? _emerald : _line,
          ),
        const SizedBox(height: 28),
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          onSubmitted: (_) {
            if (canSubmit) onSubmit();
          },
          onChanged: (_) => onChanged(),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Nombre del perfil',
            hintStyle: const TextStyle(color: _muted),
            filled: true,
            fillColor: const Color(0xFF131316),
            border: border(_line),
            enabledBorder: border(_line),
            focusedBorder: border(_emerald, 2),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: _emerald,
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF1E1E22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Caricatura sobre un círculo oscuro con borde (las imágenes son PNG
/// transparentes y flotaban).
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.seed,
    required this.name,
    required this.radius,
    required this.ringColor,
  });

  final String seed;
  final String name;
  final double radius;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: EdgeInsets.all(radius * .14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF17171B),
        border: Border.all(color: ringColor, width: 2),
      ),
      child: HourTvProfileAvatar(
        profileName: name,
        avatarSeed: seed,
        radius: radius * .86,
      ),
    );
  }
}
