import 'package:flutter/material.dart';

import '../theme/hybrid_mobile_tokens.dart';

class HybridBottomNavigation extends StatelessWidget {
  const HybridBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({String label, IconData icon})>[
    (label: 'Inicio', icon: Icons.home_rounded),
    (label: 'TV', icon: Icons.live_tv_rounded),
    (label: 'Buscar', icon: Icons.search_rounded),
    (label: 'Mi Biblioteca', icon: Icons.bookmark_border_rounded),
    (label: 'Perfil', icon: Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HybridMobileTokens.header,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: HybridMobileTokens.bottomNavigationHeight,
          child: Row(
            children: <Widget>[
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: _Destination(
                    label: _items[index].label,
                    icon: _items[index].icon,
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? HybridMobileTokens.accent
        : HybridMobileTokens.textSecondary;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 21, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: HybridMobileTypography.caption.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: label == 'Mi Biblioteca' ? 9 : 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
