import 'package:flutter/material.dart';

import '../theme/hybrid_mobile_tokens.dart';

class HybridSectionHeader extends StatelessWidget {
  const HybridSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
  });

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HybridMobileTypography.title,
          ),
        ),
        if (onViewAll != null)
          InkWell(
            onTap: onViewAll,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: HybridMobileTokens.minTouchTarget,
                minHeight: HybridMobileTokens.minTouchTarget,
              ),
              child: const Align(
                alignment: Alignment.topRight,
                child: Text(
                  'Ver todo',
                  style: TextStyle(
                    fontFamily: HybridMobileTypography.family,
                    color: HybridMobileTokens.accent,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
