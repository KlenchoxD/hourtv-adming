import 'package:flutter/material.dart';
import '../services/migration/guest_migration_service.dart';

const _surface = Color(0xFF111113);
const _line = Color(0xFF29292E);
const _muted = Color(0xFFA6A6B0);
const _emerald = Color(0xFF00C781);

class HourTvGuestImportPrompt extends StatelessWidget {
  const HourTvGuestImportPrompt({
    super.key,
    required this.summary,
    required this.onDecision,
  });

  final GuestMigrationSummary summary;
  final ValueChanged<GuestMigrationDecision> onDecision;

  String _buildDescription() {
    final fav = summary.favoriteCount;
    final prog = summary.progressCount;
    final favText = fav == 1 ? '1 favorito' : '$fav favoritos';
    final progText = prog == 1 ? 'progreso en 1 título' : 'progreso en $prog títulos';

    if (fav > 0 && prog > 0) {
      return '$favText y $progText podrán vincularse a este perfil cuando se active la sincronización.';
    } else if (fav > 0) {
      return '$favText podrán vincularse a este perfil cuando se active la sincronización.';
    } else if (prog > 0) {
      return '$progText podrán vincularse a este perfil cuando se active la sincronización.';
    } else {
      return 'Tus datos del modo invitado podrán vincularse a este perfil cuando se active la sincronización.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: _emerald,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Encontramos datos del modo invitado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _buildDescription(),
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => onDecision(GuestMigrationDecision.declined),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: const Text('Ahora no'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () =>
                    onDecision(GuestMigrationDecision.acceptedForPhase3),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Conservar para importar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
