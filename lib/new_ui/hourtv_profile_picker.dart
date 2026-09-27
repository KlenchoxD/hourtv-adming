import 'package:flutter/material.dart';

import '../mobile_ui/hourtv_mobile_components.dart';
import 'hourtv_profile_avatar.dart';

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
                  if (header != null) ...[
                    header!,
                    const SizedBox(height: 24),
                  ],
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
                // Fondo circular: las caricaturas son PNG transparentes y
                // flotaban; así combinan con el círculo de "Agregar perfil".
                Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF17171B),
                    border: Border.all(
                      color: profile.isKids ? _emerald : _line,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: HourTvProfileAvatar(
                    profileName: profile.name,
                    avatarSeed: profile.avatarSeed,
                    radius: radius - 8,
                  ),
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
