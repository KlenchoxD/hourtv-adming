import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _hourTvRed = Color(0xFF00C781);

/// Elemento interactivo del diseño nuevo para control remoto, teclado y toque.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChange,
    this.onKeyEvent,
    this.decorated = true,
    this.scale = 1.07,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Si es false, no dibuja borde/glow propios (solo escala + foco + tecla);
  /// el hijo decide su resalte. Util cuando el borde debe ir solo en la
  /// caratula y no alrededor del titulo.
  final bool decorated;
  final double scale;

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
  void didUpdateWidget(covariant TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    if (oldWidget.focusNode == null) _node.dispose();
    _node = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  void _onFocus(bool focused) {
    if (mounted) setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
    if (!focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_node.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: .5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final customResult = widget.onKeyEvent?.call(_node, event);
    if (customResult != null && customResult != KeyEventResult.ignored) {
      return customResult;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final activationKeys = {
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.gameButtonA,
    };
    if (!activationKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    widget.onTap?.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: _onFocus,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? widget.scale : 1,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          child: widget.decorated
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: _focused ? _hourTvRed : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: _focused
                        ? [
                            BoxShadow(
                              color: _hourTvRed.withValues(alpha: .5),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }
}
