import 'package:flutter/material.dart';

import '../foundation/studio_tokens.dart';

Future<T?> showStudioModalSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: StudioColors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => StudioModalSheet(
      title: title,
      subtitle: subtitle,
      onClose: () => Navigator.of(context).pop(),
      child: child,
    ),
  );
}

class StudioModalSheet extends StatelessWidget {
  const StudioModalSheet({
    super.key,
    required this.child,
    required this.onClose,
    this.title,
    this.subtitle,
  });

  final Widget child;
  final VoidCallback onClose;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - 20,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: StudioColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(StudioRadii.sheet),
          ),
          border: Border(top: BorderSide(color: StudioColors.border)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0xD9000000),
              blurRadius: 40,
              offset: Offset(0, -12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: StudioColors.border,
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                  ),
                  child: SizedBox(width: 40, height: 6),
                ),
              ),
              if (title != null || subtitle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (title != null)
                              Text(
                                title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StudioTypography.title.copyWith(
                                  fontSize: 16,
                                ),
                              ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StudioTypography.caption,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        tooltip: 'Cerrar',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: StudioColors.textMuted,
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
