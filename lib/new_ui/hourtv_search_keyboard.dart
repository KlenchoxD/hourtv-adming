import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hourtv_focusable.dart';

const _red = Color(0xFF00C781);
const _surface = Color(0xFF101412);
const _line = Color(0xFF27302C);
const _muted = Color(0xFFA6A6B0);

/// Teclado en pantalla navegable con el control (D-pad), sin depender del
/// IME del sistema. Compartido entre el buscador general y el buscador de
/// canales de TV en vivo: cada uno mantiene su propio estado de texto, este
/// widget solo reporta lo que se escribe via [onChanged].
class TvSearchKeyboard extends StatefulWidget {
  const TvSearchKeyboard({
    super.key,
    required this.query,
    required this.onChanged,
    this.hint = 'Escribe con el control…',
    this.firstKeyFocusNode,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final String hint;

  /// Foco explicito para la primera tecla ('A'): quien abre el teclado desde
  /// un contexto donde otro nodo ya tiene el foco (por ejemplo el remoteFocus
  /// de la guia de TV en vivo) necesita pedirlo a mano, porque `autofocus`
  /// no roba el foco de un nodo que ya esta enfocado en el mismo scope.
  final FocusNode? firstKeyFocusNode;

  static const _rows = <String>[
    'ABCDEFG',
    'HIJKLMN',
    'OPQRSTU',
    'VWXYZ01',
    '23456789',
  ];

  @override
  State<TvSearchKeyboard> createState() => _TvSearchKeyboardState();
}

bool matchesTvSearch(String candidate, String query) {
  final terms = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty);
  final normalizedCandidate = candidate.toLowerCase();
  return terms.every(normalizedCandidate.contains);
}

class _TvSearchKeyboardState extends State<TvSearchKeyboard> {
  static const _columnCount = 7;
  static const _letterKeyCount = 35;
  static const _actionKeyCount = 3;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(
      _letterKeyCount + _actionKeyCount,
      (index) => index == 0 && widget.firstKeyFocusNode != null
          ? widget.firstKeyFocusNode!
          : FocusNode(debugLabel: _debugLabel(index)),
    );
  }

  @override
  void didUpdateWidget(covariant TvSearchKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firstKeyFocusNode == widget.firstKeyFocusNode) return;
    if (oldWidget.firstKeyFocusNode == null) _focusNodes.first.dispose();
    _focusNodes[0] =
        widget.firstKeyFocusNode ?? FocusNode(debugLabel: _debugLabel(0));
  }

  @override
  void dispose() {
    for (var index = 0; index < _focusNodes.length; index++) {
      if (index == 0 && widget.firstKeyFocusNode != null) continue;
      _focusNodes[index].dispose();
    }
    super.dispose();
  }

  static String _debugLabel(int index) {
    if (index < _letterKeyCount) {
      final row = index ~/ _columnCount;
      final column = index % _columnCount;
      return 'TV Search ${TvSearchKeyboard._rows[row][column]}';
    }
    return switch (index - _letterKeyCount) {
      0 => 'TV Search Borrar todo',
      1 => 'TV Search Espacio',
      _ => 'TV Search Borrar carácter',
    };
  }

  void _type(String ch) => widget.onChanged(widget.query + ch);
  void _back() => widget.onChanged(
    widget.query.isEmpty
        ? ''
        : widget.query.substring(0, widget.query.length - 1),
  );

  KeyEventResult _moveFocus(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    int? target;
    final key = event.logicalKey;
    if (index < _letterKeyCount) {
      final row = index ~/ _columnCount;
      final column = index % _columnCount;
      if (key == LogicalKeyboardKey.arrowLeft && column > 0) {
        target = index - 1;
      } else if (key == LogicalKeyboardKey.arrowRight &&
          column < _columnCount - 1) {
        target = index + 1;
      } else if (key == LogicalKeyboardKey.arrowUp && row > 0) {
        target = index - _columnCount;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        if (row < 4) {
          target = index + _columnCount;
        } else {
          target = _letterKeyCount + (column < 3 ? 0 : (column < 5 ? 1 : 2));
        }
      }
    } else {
      final action = index - _letterKeyCount;
      if (key == LogicalKeyboardKey.arrowLeft && action > 0) {
        target = index - 1;
      } else if (key == LogicalKeyboardKey.arrowRight &&
          action < _actionKeyCount - 1) {
        target = index + 1;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        target =
            28 +
            switch (action) {
              0 => 1,
              1 => 3,
              _ => 5,
            };
      }
    }

    if (target == null) return KeyEventResult.ignored;
    _focusNodes[target].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 372,
          height: 46,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: _muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.query.isEmpty ? widget.hint : widget.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.query.isEmpty ? _muted : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var r = 0; r < TvSearchKeyboard._rows.length; r++) ...[
          Row(
            children: [
              for (var c = 0; c < TvSearchKeyboard._rows[r].length; c++) ...[
                TvKeyCap(
                  label: TvSearchKeyboard._rows[r][c],
                  autofocus: r == 0 && c == 0,
                  focusNode: _focusNodes[r * _columnCount + c],
                  onKeyEvent: (node, event) =>
                      _moveFocus(r * _columnCount + c, event),
                  onTap: () => _type(TvSearchKeyboard._rows[r][c]),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            TvKeyCap(
              label: 'Borrar',
              wide: true,
              focusNode: _focusNodes[35],
              onKeyEvent: (node, event) => _moveFocus(35, event),
              onTap: () => widget.onChanged(''),
            ),
            const SizedBox(width: 6),
            TvKeyCap(
              label: 'Espacio',
              wide: true,
              focusNode: _focusNodes[36],
              onKeyEvent: (node, event) => _moveFocus(36, event),
              onTap: () => _type(' '),
            ),
            const SizedBox(width: 6),
            TvKeyCap(
              icon: Icons.backspace_outlined,
              semanticLabel: 'Borrar carácter',
              focusNode: _focusNodes[37],
              onKeyEvent: (node, event) => _moveFocus(37, event),
              onTap: _back,
            ),
          ],
        ),
      ],
    );
  }
}

class TvKeyCap extends StatefulWidget {
  const TvKeyCap({
    super.key,
    this.label,
    this.icon,
    this.wide = false,
    this.autofocus = false,
    this.focusNode,
    this.onKeyEvent,
    this.semanticLabel,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final bool wide;
  final bool autofocus;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  State<TvKeyCap> createState() => _TvKeyCapState();
}

class _TvKeyCapState extends State<TvKeyCap> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: widget.onTap,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      decorated: false,
      scale: 1.12,
      borderRadius: BorderRadius.circular(10),
      onFocusChange: (value) => setState(() => _focused = value),
      child: Semantics(
        button: true,
        label: widget.semanticLabel ?? widget.label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: widget.wide ? 96 : 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _focused ? _red : _surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _focused ? _red : _line),
          ),
          child: widget.icon != null
              ? Icon(widget.icon, color: Colors.white, size: 18)
              : Text(
                  widget.label!,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: widget.wide ? 13 : 15,
                  ),
                ),
        ),
      ),
    );
  }
}
