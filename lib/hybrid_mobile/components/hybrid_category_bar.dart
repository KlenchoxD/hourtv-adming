import 'package:flutter/material.dart';

import '../theme/hybrid_mobile_tokens.dart';

class HybridCategoryBar extends StatelessWidget {
  const HybridCategoryBar({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HybridMobileTokens.minTouchTarget,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: HybridMobileTokens.md),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: HybridMobileTokens.sm),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return Semantics(
            label: category,
            button: true,
            selected: isSelected,
            child: ExcludeSemantics(
              child: Center(
                child: Material(
                  color: isSelected
                      ? HybridMobileTokens.accent
                      : HybridMobileTokens.surface,
                  borderRadius: BorderRadius.circular(
                    HybridMobileTokens.radiusRound,
                  ),
                  child: InkWell(
                    key: ValueKey<String>('hybrid-category-$category'),
                    onTap: () => onSelected(category),
                    borderRadius: BorderRadius.circular(
                      HybridMobileTokens.radiusRound,
                    ),
                    splashColor: Colors.transparent,
                    highlightColor: HybridMobileTokens.accentSoft,
                    focusColor: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 36),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: HybridMobileTokens.lg,
                          vertical: HybridMobileTokens.sm,
                        ),
                        child: Text(
                          category,
                          style: HybridMobileTypography.label.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
