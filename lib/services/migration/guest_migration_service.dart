import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum GuestMigrationDecision {
  pending,
  declined,
  acceptedForPhase3,
}

class GuestMigrationSummary {
  const GuestMigrationSummary({
    required this.localProfileId,
    required this.favoriteCount,
    required this.progressCount,
    required this.recentCount,
  });

  final String localProfileId;
  final int favoriteCount;
  final int progressCount;
  final int recentCount;

  bool get hasMeaningfulData =>
      favoriteCount > 0 || progressCount > 0 || recentCount > 0;

  Map<String, dynamic> toJson() => {
        'localProfileId': localProfileId,
        'favoriteCount': favoriteCount,
        'progressCount': progressCount,
        'recentCount': recentCount,
      };
}

class GuestMigrationService {
  GuestMigrationService({SharedPreferences? prefs}) : _prefsInstance = prefs;

  final SharedPreferences? _prefsInstance;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  static String _decisionKey(String accountId, String localProfileId) =>
      'guest_migration_decision.${accountId}_$localProfileId';

  Future<GuestMigrationSummary> inspect({String localProfileId = 'invitado'}) async {
    final prefs = await _getPrefs();
    int favoriteCount = 0;
    int progressCount = 0;
    int recentCount = 0;

    final favRaw = prefs.getString('favorites.profile.$localProfileId');
    if (favRaw != null) {
      try {
        final decoded = jsonDecode(favRaw);
        if (decoded is List) {
          favoriteCount = decoded.length;
        }
      } catch (_) {}
    }

    final recentRaw = prefs.getString('recent_channels.profile.$localProfileId');
    if (recentRaw != null) {
      try {
        final decoded = jsonDecode(recentRaw);
        if (decoded is List) {
          recentCount = decoded.length;
          for (final item in decoded) {
            if (item is Map) {
              final fraction = item['progressFraction'];
              if (fraction is num && fraction > 0) {
                progressCount++;
              }
            }
          }
        }
      } catch (_) {}
    }

    return GuestMigrationSummary(
      localProfileId: localProfileId,
      favoriteCount: favoriteCount,
      progressCount: progressCount,
      recentCount: recentCount,
    );
  }

  Future<GuestMigrationDecision> getDecision(
    String accountId, {
    String localProfileId = 'invitado',
  }) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_decisionKey(accountId, localProfileId));
    if (raw == null) return GuestMigrationDecision.pending;
    return switch (raw) {
      'acceptedForPhase3' => GuestMigrationDecision.acceptedForPhase3,
      'declined' => GuestMigrationDecision.declined,
      _ => GuestMigrationDecision.pending,
    };
  }

  Future<void> rememberDecision(
    String accountId,
    GuestMigrationDecision decision, {
    String localProfileId = 'invitado',
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(_decisionKey(accountId, localProfileId), decision.name);
  }
}
