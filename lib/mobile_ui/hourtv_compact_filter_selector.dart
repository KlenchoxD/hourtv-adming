import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Selector de filtro compacto tipo tarjeta (48 px de alto) con renderizado
/// progresivo de chips para garantizar aperturas inmediatas (<32ms).
class HourTvCompactFilterSelector extends StatelessWidget {
  const HourTvCompactFilterSelector({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon = Icons.layers_rounded,
    this.sheetTitle,
    this.sheetSubtitle,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final String? sheetTitle;
  final String? sheetSubtitle;

  static const _emerald = Color(0xFF00C781);
  static const _surface = Color(0xFF101412);
  static const _border = Color(0xFF27302C);
  static const _muted = Color(0xFFA6A6B0);

  Future<void> _openSheet(BuildContext context) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[PERF_MODAL] SHEET_OPEN: $label start=$start');

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface,
      barrierColor: Colors.black.withValues(alpha: .72),
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 150),
        reverseDuration: Duration(milliseconds: 120),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => _FilterSheetBody(
        label: label,
        value: value,
        options: options,
        icon: icon,
        sheetTitle: sheetTitle,
        sheetSubtitle: sheetSubtitle,
        startMs: start,
        onSelect: (val) => Navigator.pop(sheetContext, val),
      ),
    );

    if (selected != null && selected != value) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Icon(icon, color: _emerald, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: _muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheetBody extends StatefulWidget {
  const _FilterSheetBody({
    required this.label,
    required this.value,
    required this.options,
    required this.icon,
    this.sheetTitle,
    this.sheetSubtitle,
    required this.startMs,
    required this.onSelect,
  });

  final String label;
  final String value;
  final List<String> options;
  final IconData icon;
  final String? sheetTitle;
  final String? sheetSubtitle;
  final int startMs;
  final ValueChanged<String> onSelect;

  @override
  State<_FilterSheetBody> createState() => _FilterSheetBodyState();
}

class _FilterSheetBodyState extends State<_FilterSheetBody> {
  bool _showAll = false;

  static const _emerald = Color(0xFF00C781);
  static const _surfaceOption = Color(0xFF151917);
  static const _border = Color(0xFF27302C);
  static const _muted = Color(0xFFA6A6B0);

  static final _chipRadius = BorderRadius.circular(12);
  static const _activeBorder = Border.fromBorderSide(BorderSide(color: _emerald));
  static const _inactiveBorder = Border.fromBorderSide(BorderSide(color: _border));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final end = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[PERF_MODAL] SHEET_RENDERED: ${widget.label} elapsedMs=${end - widget.startMs}');
      if (mounted && !_showAll && widget.options.length > 3) {
        setState(() => _showAll = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayedOptions = _showAll
        ? widget.options
        : widget.options.take(math.min(widget.options.length, 3)).toList(growable: false);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.sheetTitle ?? widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.sheetSubtitle ?? 'Selecciona una opción',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: GridView.builder(
                  itemCount: displayedOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.25,
                  ),
                  itemBuilder: (context, index) {
                    final item = displayedOptions[index];
                    final active = item == widget.value;
                    return Material(
                      color: active ? _emerald : _surfaceOption,
                      borderRadius: _chipRadius,
                      child: InkWell(
                        onTap: () => widget.onSelect(item),
                        borderRadius: _chipRadius,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: _chipRadius,
                            border: active ? _activeBorder : _inactiveBorder,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.startsWith('Todos') || item == 'Todo'
                                    ? Icons.apps_rounded
                                    : widget.icon,
                                size: 16,
                                color: active ? Colors.black : _emerald,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: active ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (active)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.black,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
