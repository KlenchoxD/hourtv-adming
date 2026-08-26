import 'package:flutter/material.dart';

import '../foundation/studio_tokens.dart';

enum StudioButtonVariant { primary, secondary, white, danger }

enum StudioButtonSize { small, medium, large }

class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = StudioButtonVariant.primary,
    this.size = StudioButtonSize.medium,
    this.isLoading = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final StudioButtonVariant variant;
  final StudioButtonSize size;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final visual = _visualFor(variant);
    final horizontalPadding = switch (size) {
      StudioButtonSize.small => 16.0,
      StudioButtonSize.medium => 20.0,
      StudioButtonSize.large => 24.0,
    };
    final fontSize = switch (size) {
      StudioButtonSize.small => 14.0,
      StudioButtonSize.medium => 16.0,
      StudioButtonSize.large => 18.0,
    };

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled
            ? visual.background
            : visual.background.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudioRadii.control),
          side: visual.border == null
              ? BorderSide.none
              : BorderSide(color: visual.border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: StudioSpacing.touchTarget,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: size == StudioButtonSize.large ? 14 : 10,
              ),
              child: Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (isLoading)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: visual.foreground,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 20, color: visual.foreground),
                  if (isLoading || icon != null)
                    const SizedBox(width: StudioSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: StudioTypography.family,
                        fontSize: fontSize,
                        height: 1.15,
                        fontWeight:
                            variant == StudioButtonVariant.primary ||
                                variant == StudioButtonVariant.white
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: enabled
                            ? visual.foreground
                            : visual.foreground.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  _StudioButtonVisual _visualFor(StudioButtonVariant value) {
    return switch (value) {
      StudioButtonVariant.primary => const _StudioButtonVisual(
        background: StudioColors.accent,
        foreground: StudioColors.deepBlack,
      ),
      StudioButtonVariant.secondary => const _StudioButtonVisual(
        background: StudioColors.surfaceElevated,
        foreground: StudioColors.textPrimary,
        border: StudioColors.border,
      ),
      StudioButtonVariant.white => const _StudioButtonVisual(
        background: StudioColors.textPrimary,
        foreground: StudioColors.deepBlack,
      ),
      StudioButtonVariant.danger => const _StudioButtonVisual(
        background: Color(0xFF1E1414),
        foreground: Color(0xFFF87171),
        border: Color(0x667F1D1D),
      ),
    };
  }
}

class _StudioButtonVisual {
  const _StudioButtonVisual({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}

enum StudioIconButtonVariant { surface, ghost, emerald, glass }

class StudioIconButton extends StatelessWidget {
  const StudioIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticsLabel,
    this.variant = StudioIconButtonVariant.surface,
    this.size = 48,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticsLabel;
  final StudioIconButtonVariant variant;
  final double size;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size.clamp(48, double.infinity).toDouble();
    final background = switch (variant) {
      StudioIconButtonVariant.surface => StudioColors.surfaceElevated,
      StudioIconButtonVariant.ghost => StudioColors.transparent,
      StudioIconButtonVariant.emerald => StudioColors.accent,
      StudioIconButtonVariant.glass => StudioColors.deepBlack.withValues(
        alpha: 0.7,
      ),
    };
    final foreground = variant == StudioIconButtonVariant.emerald
        ? StudioColors.deepBlack
        : StudioColors.textPrimary;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: SizedBox.square(
        dimension: effectiveSize,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Material(
                color: background,
                shape: CircleBorder(
                  side:
                      variant == StudioIconButtonVariant.surface ||
                          variant == StudioIconButtonVariant.glass
                      ? const BorderSide(color: StudioColors.border)
                      : BorderSide.none,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Icon(
                    icon,
                    size: effectiveSize * 0.42,
                    color: foreground,
                  ),
                ),
              ),
            ),
            if (badge)
              const Positioned(
                top: 4,
                right: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: StudioColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
