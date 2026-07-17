import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tv_focusable.dart';

class TvVodDetailPrimaryActions extends StatelessWidget {
  final VoidCallback? onPlay;
  final bool autofocus;
  final IconData? secondaryIcon;
  final String? secondaryLabel;
  final bool secondarySelected;
  final VoidCallback? onSecondaryTap;
  final double scale;

  const TvVodDetailPrimaryActions({
    super.key,
    required this.onPlay,
    required this.autofocus,
    required this.scale,
    this.secondaryIcon,
    this.secondaryLabel,
    this.secondarySelected = false,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TvFocusable(
        autofocus: autofocus,
        onTap: onPlay,
        borderRadius: BorderRadius.circular(8 * scale),
        child: AnimatedOpacity(
          opacity: onPlay == null ? 0.45 : 1,
          duration: const Duration(milliseconds: 160),
          child: Container(
            height: 48 * scale,
            padding: EdgeInsets.symmetric(horizontal: 20 * scale),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8 * scale),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 25 * scale,
                ),
                SizedBox(width: 7 * scale),
                Text(
                  'Reproducir',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (secondaryLabel != null && onSecondaryTap != null) ...[
        SizedBox(width: 12 * scale),
        TvFocusable(
          onTap: onSecondaryTap,
          borderRadius: BorderRadius.circular(8 * scale),
          child: Container(
            height: 48 * scale,
            padding: EdgeInsets.symmetric(horizontal: 17 * scale),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8 * scale),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secondaryIcon != null) ...[
                  Icon(
                    secondaryIcon,
                    color: secondarySelected
                        ? AppColors.accentLight
                        : Colors.white,
                    size: 21 * scale,
                  ),
                  SizedBox(width: 7 * scale),
                ],
                Text(
                  secondaryLabel!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class TvVodDetailInlineAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double scale;

  const TvVodDetailInlineAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scale,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => TvFocusable(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6 * scale),
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 5 * scale),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? AppColors.accentLight : AppColors.textSecondary,
            size: 18 * scale,
          ),
          SizedBox(width: 6 * scale),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accentLight : AppColors.textSecondary,
              fontSize: 12.5 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
