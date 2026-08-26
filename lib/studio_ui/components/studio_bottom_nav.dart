import 'package:flutter/material.dart';

import '../foundation/studio_tokens.dart';

class StudioBottomNav extends StatelessWidget {
  const StudioBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.hasPendingProfileUpdate = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool hasPendingProfileUpdate;

  static const _items = <({String label, IconData icon})>[
    (label: 'Inicio', icon: Icons.home_outlined),
    (label: 'TV', icon: Icons.live_tv_outlined),
    (label: 'Buscar', icon: Icons.search_rounded),
    (label: 'Mi Biblioteca', icon: Icons.bookmark_border_rounded),
    (label: 'Perfil', icon: Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(color: StudioColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          children: <Widget>[
            for (var index = 0; index < _items.length; index++)
              Expanded(
                child: _StudioNavItem(
                  key: ValueKey<String>('bottom-nav-${_items[index].label}'),
                  item: _items[index],
                  selected: selectedIndex == index,
                  showBadge: index == 4 && hasPendingProfileUpdate,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudioNavItem extends StatelessWidget {
  const _StudioNavItem({
    super.key,
    required this.item,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  final ({String label, IconData icon}) item;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: StudioColors.transparent,
        borderRadius: BorderRadius.circular(StudioRadii.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Icon(
                        item.icon,
                        size: selected ? 22 : 20,
                        color: selected
                            ? StudioColors.accent
                            : StudioColors.textMuted,
                      ),
                      if (showBadge)
                        const Positioned(
                          top: -1,
                          right: -2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: StudioColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox.square(dimension: 8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: StudioTypography.family,
                      fontSize: 10.5,
                      height: 1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? StudioColors.textPrimary
                          : StudioColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return selected
        ? KeyedSubtree(
            key: ValueKey<String>('bottom-nav-selected-${item.label}'),
            child: content,
          )
        : content;
  }
}
