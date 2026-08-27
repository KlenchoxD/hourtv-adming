import 'package:flutter/material.dart';

import '../theme/hybrid_mobile_tokens.dart';

class HybridBrandHeader extends StatelessWidget {
  const HybridBrandHeader({
    super.key,
    required this.onFilter,
    required this.onSearch,
  });

  final VoidCallback onFilter;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HybridMobileTokens.header,
      child: SizedBox(
        height: HybridMobileTokens.headerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HybridMobileTokens.md),
          child: Row(
            children: <Widget>[
              Semantics(
                label: 'HourTV',
                image: true,
                child: ExcludeSemantics(
                  child: Image.asset(
                    'assets/branding/hourtv_logo.png',
                    key: const ValueKey<String>('hybrid-hourtv-logo'),
                    width: 88,
                    height: 40,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              const Spacer(),
              _HeaderAction(
                label: 'Filtrar',
                icon: Icons.tune_rounded,
                onPressed: onFilter,
              ),
              _HeaderAction(
                label: 'Buscar',
                icon: Icons.search_rounded,
                onPressed: onSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: HybridMobileTokens.minTouchTarget,
          child: IconButton(
            onPressed: onPressed,
            tooltip: label,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            icon: Icon(icon, color: HybridMobileTokens.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}
