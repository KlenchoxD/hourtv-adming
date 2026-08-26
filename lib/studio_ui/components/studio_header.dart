import 'package:flutter/material.dart';

import '../foundation/studio_tokens.dart';
import 'studio_button.dart';
import 'studio_logo.dart';

class StudioHeader extends StatelessWidget {
  const StudioHeader({
    super.key,
    required this.profileName,
    required this.onHome,
    required this.onProfile,
    this.onCast,
    this.showCast = false,
    this.isOffline = false,
    this.avatarColor = StudioColors.accent,
  });

  final String profileName;
  final VoidCallback onHome;
  final VoidCallback onProfile;
  final VoidCallback? onCast;
  final bool showCast;
  final bool isOffline;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: StudioColors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Semantics(
                button: true,
                label: 'Ir a Inicio HourTV',
                child: Material(
                  color: StudioColors.transparent,
                  borderRadius: BorderRadius.circular(StudioRadii.small),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onHome,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: StudioLogo(size: StudioLogoSize.small),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (isOffline)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: StudioColors.border,
                    borderRadius: BorderRadius.circular(StudioRadii.round),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 14,
                        color: StudioColors.accent,
                      ),
                      SizedBox(width: 6),
                      Text('Sin conexión', style: StudioTypography.caption),
                    ],
                  ),
                ),
              if (showCast) ...<Widget>[
                const SizedBox(width: StudioSpacing.sm),
                StudioIconButton(
                  icon: Icons.cast_rounded,
                  onPressed: onCast,
                  semanticsLabel: 'Transmitir a un dispositivo',
                  variant: StudioIconButtonVariant.ghost,
                ),
              ],
              const SizedBox(width: StudioSpacing.sm),
              Semantics(
                button: true,
                label: 'Perfil de $profileName',
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: Material(
                      color: avatarColor,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onProfile,
                        child: SizedBox.square(
                          dimension: 36,
                          child: Center(
                            child: Text(
                              profileName.trim().isEmpty
                                  ? '?'
                                  : profileName.trim()[0].toUpperCase(),
                              style: const TextStyle(
                                fontFamily: StudioTypography.family,
                                color: StudioColors.deepBlack,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
