import 'package:flutter/material.dart';

import 'hourtv_focusable.dart';

const _red = Color(0xFFF20A1A);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

/// Teclado en pantalla navegable con el control (D-pad), sin depender del
/// IME del sistema. Compartido entre el buscador general y el buscador de
/// canales de TV en vivo: cada uno mantiene su propio estado de texto, este
/// widget solo reporta lo que se escribe via [onChanged].
class TvSearchKeyboard extends StatelessWidget {
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

  void _type(String ch) => onChanged(query + ch);
  void _back() =>
      onChanged(query.isEmpty ? '' : query.substring(0, query.length - 1));

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
                  query.isEmpty ? hint : query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: query.isEmpty ? _muted : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var r = 0; r < _rows.length; r++) ...[
          Row(
            children: [
              for (final ch in _rows[r].split('')) ...[
                TvKeyCap(
                  label: ch,
                  autofocus: r == 0 && ch == 'A',
                  focusNode: (r == 0 && ch == 'A') ? firstKeyFocusNode : null,
                  onTap: () => _type(ch),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            TvKeyCap(label: 'Espacio', wide: true, onTap: () => _type(' ')),
            const SizedBox(width: 6),
            TvKeyCap(icon: Icons.backspace_outlined, onTap: _back),
            const SizedBox(width: 6),
            TvKeyCap(icon: Icons.close_rounded, onTap: () => onChanged('')),
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
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final bool wide;
  final bool autofocus;
  final FocusNode? focusNode;
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
      decorated: false,
      scale: 1.12,
      borderRadius: BorderRadius.circular(10),
      onFocusChange: (value) => setState(() => _focused = value),
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
    );
  }
}
