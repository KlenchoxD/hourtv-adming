import 'dart:async';

import 'package:flutter/material.dart';

import '../foundation/studio_tokens.dart';

enum StudioSnackbarType { success, warning, info }

class StudioSnackbar extends StatefulWidget {
  const StudioSnackbar({
    super.key,
    required this.message,
    required this.onDismiss,
    this.type = StudioSnackbarType.success,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 4),
  });

  final String message;
  final VoidCallback onDismiss;
  final StudioSnackbarType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  @override
  State<StudioSnackbar> createState() => _StudioSnackbarState();
}

class _StudioSnackbarState extends State<StudioSnackbar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (widget.type) {
      StudioSnackbarType.success => Icons.check_circle_outline_rounded,
      StudioSnackbarType.warning => Icons.error_outline_rounded,
      StudioSnackbarType.info => Icons.info_outline_rounded,
    };
    final color = switch (widget.type) {
      StudioSnackbarType.success => StudioColors.accent,
      StudioSnackbarType.warning => StudioColors.warning,
      StudioSnackbarType.info => const Color(0xFF38BDF8),
    };

    return Semantics(
      liveRegion: true,
      label: widget.message,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        decoration: BoxDecoration(
          color: StudioColors.surfaceElevated.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(StudioRadii.control),
          border: Border.all(color: StudioColors.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xD9000000),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: StudioTypography.label,
              ),
            ),
            if (widget.actionLabel != null && widget.onAction != null)
              TextButton(
                onPressed: () {
                  widget.onAction!();
                  widget.onDismiss();
                },
                child: Text(widget.actionLabel!),
              ),
            IconButton(
              onPressed: widget.onDismiss,
              tooltip: 'Cerrar notificación',
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: const Icon(Icons.close_rounded, size: 18),
              color: StudioColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
