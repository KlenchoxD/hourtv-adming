import 'package:flutter/material.dart';

ThemeData hourTvWebInteractionTheme(ThemeData base) {
  final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) return Colors.transparent;
    if (states.contains(WidgetState.pressed)) return const Color(0x3300C781);
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return const Color(0x2200C781);
    }
    return Colors.transparent;
  });
  final style = ButtonStyle(
    overlayColor: overlay,
    animationDuration: const Duration(milliseconds: 160),
    mouseCursor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
    ),
  );
  return base.copyWith(
    hoverColor: const Color(0x2200C781),
    focusColor: const Color(0x2200C781),
    splashColor: const Color(0x3300C781),
    highlightColor: const Color(0x1800C781),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.merge(style) ?? style,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.merge(style) ?? style,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: base.elevatedButtonTheme.style?.merge(style) ?? style,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.merge(style) ?? style,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: base.iconButtonTheme.style?.merge(style) ?? style,
    ),
  );
}
