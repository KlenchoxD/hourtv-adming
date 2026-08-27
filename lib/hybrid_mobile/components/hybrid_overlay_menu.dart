import 'package:flutter/material.dart';

import '../theme/hybrid_mobile_tokens.dart';

class HybridOverlayMenu<T> extends StatelessWidget {
  const HybridOverlayMenu({
    super.key,
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onSelected,
    this.width = 152,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(
          HybridMobileTokens.surfaceElevated,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              HybridMobileTokens.radiusControl,
            ),
            side: const BorderSide(color: HybridMobileTokens.border),
          ),
        ),
        maximumSize: WidgetStatePropertyAll(Size(width, 320)),
      ),
      menuChildren: <Widget>[
        for (final option in values)
          MenuItemButton(
            onPressed: () => onSelected(option),
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(
                Size(width - 8, HybridMobileTokens.minTouchTarget),
              ),
              foregroundColor: const WidgetStatePropertyAll(
                HybridMobileTokens.textPrimary,
              ),
              backgroundColor: WidgetStatePropertyAll(
                option == value
                    ? HybridMobileTokens.accentSoft
                    : Colors.transparent,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    HybridMobileTokens.radiusSmall,
                  ),
                ),
              ),
            ),
            trailingIcon: option == value
                ? const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: HybridMobileTokens.accent,
                  )
                : null,
            child: Text(
              labelBuilder(option),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HybridMobileTypography.label,
            ),
          ),
      ],
      builder: (context, controller, child) => Semantics(
        button: true,
        label: labelBuilder(value),
        child: SizedBox(
          width: width,
          height: HybridMobileTokens.minTouchTarget,
          child: OutlinedButton(
            onPressed: controller.isOpen ? controller.close : controller.open,
            style: OutlinedButton.styleFrom(
              foregroundColor: HybridMobileTokens.textPrimary,
              backgroundColor: HybridMobileTokens.surface,
              side: const BorderSide(color: HybridMobileTokens.border),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  HybridMobileTokens.radiusControl,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    labelBuilder(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HybridMobileTypography.label,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  controller.isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
