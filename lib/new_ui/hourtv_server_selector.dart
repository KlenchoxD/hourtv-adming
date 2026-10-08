import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../mobile_ui/hourtv_mobile_theme.dart';

/// Bounded dialog: fixed header, one scrollable list and a full-row hit target.
class HourTvServerSelector extends StatelessWidget {
  const HourTvServerSelector({
    super.key,
    required this.servers,
    required this.activeUrl,
  });
  final List<ChannelServer> servers;
  final String? activeUrl;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ChannelServer>>{};
    for (final server in servers) {
      final language = server.language?.trim();
      groups
          .putIfAbsent(
            language?.isNotEmpty == true ? language! : 'Idioma no especificado',
            () => [],
          )
          .add(server);
    }
    final rows = <Widget>[];
    for (final group in groups.entries) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Text(
            group.key,
            style: const TextStyle(
              color: HourTvMobileTokens.emerald,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      for (final server in group.value) {
        final selected = server.url == activeUrl;
        final index = servers.indexOf(server) + 1;
        final name = server.name.trim().isEmpty
            ? 'Servidor'
            : server.name.trim();
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected
                  ? const Color(0xFF0B3024)
                  : HourTvMobileTokens.surfaceControl,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected
                      ? HourTvMobileTokens.emerald
                      : HourTvMobileTokens.borderSubtle,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                selected: selected,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(server),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.play_circle_outline_rounded,
                          color: selected
                              ? HourTvMobileTokens.emerald
                              : HourTvMobileTokens.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name · $index',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (selected)
                                const Text(
                                  'Seleccionado',
                                  style: TextStyle(
                                    color: HourTvMobileTokens.emerald,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return Dialog(
      backgroundColor: HourTvMobileTokens.surfacePrimary,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HourTvMobileTokens.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Servidores',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: HourTvMobileTokens.borderSubtle),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                children: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
