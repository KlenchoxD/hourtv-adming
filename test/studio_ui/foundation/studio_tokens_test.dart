import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/studio_ui/foundation/studio_theme.dart';
import 'package:streamtv/studio_ui/foundation/studio_tokens.dart';

void main() {
  test('uses the approved AI Studio palette and geometry tokens', () {
    expect(StudioColors.deepBlack, const Color(0xFF050505));
    expect(StudioColors.background, const Color(0xFF080A09));
    expect(StudioColors.surface, const Color(0xFF101412));
    expect(StudioColors.surfaceElevated, const Color(0xFF151917));
    expect(StudioColors.accent, const Color(0xFF00C781));
    expect(StudioColors.accentHover, const Color(0xFF00E595));
    expect(StudioColors.textPrimary, const Color(0xFFF5F5F5));
    expect(StudioColors.textSecondary, const Color(0xFFC4C8C6));
    expect(StudioColors.textMuted, const Color(0xFFA8ADAB));
    expect(StudioColors.border, const Color(0xFF27302C));
    expect(StudioSpacing.touchTarget, 48);
    expect(StudioRadii.control, 12);
  });

  test('builds a dark Inter theme without Material touch splashes', () {
    final theme = StudioTheme.build();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, StudioColors.background);
    expect(theme.colorScheme.primary, StudioColors.accent);
    expect(theme.textTheme.bodyMedium?.fontFamily, contains('Inter'));
    expect(theme.splashFactory, NoSplash.splashFactory);
  });
}
