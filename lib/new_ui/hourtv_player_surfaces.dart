import 'package:flutter/material.dart';

const playerSurface = Color(0xFF101816);
const playerAccent = Color(0xFF00C781);

ThemeData hourTvPlayerTheme(ThemeData base) => base.copyWith(
  textTheme: base.textTheme.apply(
    fontFamily: 'Roboto',
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  colorScheme: base.colorScheme.copyWith(
    primary: playerAccent,
    secondary: playerAccent,
    surface: playerSurface,
    onSurface: Colors.white,
  ),
  iconTheme: const IconThemeData(color: Color(0xFFB8BFBD), size: 22),
  dialogTheme: DialogThemeData(
    backgroundColor: playerSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xFF26342E)),
    ),
    titleTextStyle: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    contentTextStyle: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14,
      height: 1.45,
      color: Color(0xFFB8BFBD),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    textColor: Colors.white,
    iconColor: Color(0xFFB8BFBD),
    minVerticalPadding: 12,
    contentPadding: EdgeInsets.symmetric(horizontal: 16),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: playerAccent,
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);

/// A common visual language for every player dialog, including small errors
/// and selectors. It does not change their routes, return values or callbacks.
Future<T?> showHourTvPlayerDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierColor: Colors.black.withValues(alpha: .72),
  builder: (dialogContext) => Theme(
    data: hourTvPlayerTheme(Theme.of(dialogContext)),
    child: builder(dialogContext),
  ),
);

class PlayerSheetAction {
  const PlayerSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
}

class HourTvPlayerOptionsSheet extends StatelessWidget {
  const HourTvPlayerOptionsSheet({
    super.key,
    required this.title,
    required this.actions,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<PlayerSheetAction> actions;
  @override
  Widget build(BuildContext context) => Theme(
    data: hourTvPlayerTheme(Theme.of(context)),
    child: Material(
      color: playerSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle?.isNotEmpty == true) ...[
                            const SizedBox(height: 5),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Color(0xFFB8BFBD),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar opciones',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final action in actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    onTap: action.onTap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: action.selected
                        ? const Color(0xFF173328)
                        : Colors.transparent,
                    leading: Icon(
                      action.icon,
                      color: action.selected
                          ? playerAccent
                          : const Color(0xFFB8BFBD),
                    ),
                    title: Text(
                      action.label,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: action.subtitle == null
                        ? null
                        : Text(
                            action.subtitle!,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF94A49C),
                            ),
                          ),
                    trailing: Icon(
                      action.selected
                          ? Icons.check_rounded
                          : Icons.chevron_right_rounded,
                      color: action.selected ? playerAccent : Colors.white38,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
