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
        separatorBuilder: (_, _) => const SizedBox(width: 15),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return Semantics(
            label: category,
            button: true,
            selected: isSelected,
            child: ExcludeSemantics(
              child: InkWell(
                key: ValueKey<String>('hybrid-category-$category'),
                onTap: () => onSelected(category),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: HybridMobileTokens.minTouchTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(
                        category,
                        style: HybridMobileTypography.label.copyWith(
                          color: isSelected
                              ? HybridMobileTokens.accent
                              : HybridMobileTokens.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
