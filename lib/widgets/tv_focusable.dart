import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Hace que [child] sea operable con control remoto (D-pad de Android TV/Google TV)
/// y teclado (PC), ademas de tactil/mouse. Resalta con un borde cuando tiene foco
/// y activa [onTap] con Enter/Select/Espacio.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool autofocus;
  final FocusNode? focusNode;

  const TvFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _node;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final activate = {
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.gameButtonA,
    };
    if (activate.contains(event.logicalKey)) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: _focused ? AppColors.accent : Colors.transparent, width: 3),
              boxShadow: _focused
                  ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 1)]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
