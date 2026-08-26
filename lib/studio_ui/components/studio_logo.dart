import 'package:flutter/material.dart';

import '../foundation/studio_tokens.dart';

enum StudioLogoSize { small, medium, large, display }

class StudioLogo extends StatelessWidget {
  const StudioLogo({
    super.key,
    this.size = StudioLogoSize.medium,
    this.showTagline = false,
  });

  final StudioLogoSize size;
  final bool showTagline;

  double get _fontSize => switch (size) {
    StudioLogoSize.small => 22,
    StudioLogoSize.medium => 28,
    StudioLogoSize.large => 40,
    StudioLogoSize.display => 56,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'HourTV',
      image: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: const <InlineSpan>[
                  TextSpan(
                    text: 'Hour',
                    style: TextStyle(color: StudioColors.textPrimary),
                  ),
                  TextSpan(
                    text: 'TV',
                    style: TextStyle(color: StudioColors.accent),
                  ),
                ],
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: StudioTypography.family,
                fontSize: _fontSize,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -_fontSize * 0.045,
              ),
            ),
            if (showTagline) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              const Text(
                'STREAMING PREMIUM',
                style: TextStyle(
                  fontFamily: StudioTypography.family,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: StudioColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
