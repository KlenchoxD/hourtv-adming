import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/services/migration/guest_migration_service.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GuestMigrationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'favorites.profile.invitado': jsonEncode([
        {'name': 'Canal 1', 'url': 'http://ch1.m3u8'},
        {'name': 'Canal 2', 'url': 'http://ch2.m3u8'},
      ]),
      'recent_channels.profile.invitado': jsonEncode([
        {'name': 'Peli 1', 'url': 'http://p1.mp4', 'progressFraction': 0.45},
        {'name': 'Peli 2', 'url': 'http://p2.mp4', 'progressFraction': 0.80},
        {'name': 'Peli 3', 'url': 'http://p3.mp4', 'progressFraction': 0.10},
        {'name': 'Peli 4', 'url': 'http://p4.mp4', 'progressFraction': 0.0},
      ]),
    });
    await StorageService.init();
    service = GuestMigrationService();
  });

  group('GuestMigrationService', () {
    test('inspection reports counts but does not expose content payloads', () async {
      final summary = await service.inspect(localProfileId: 'invitado');
      expect(summary.favoriteCount, 2);
      expect(summary.progressCount, 3);
      expect(summary.recentCount, 4);
      expect(summary.hasMeaningfulData, isTrue);
      expect(summary.toJson().keys, unorderedEquals([
        'localProfileId', 'favoriteCount', 'progressCount', 'recentCount'
      ]));
    });

    test('acceptance remains local for Phase 3 and persists decision', () async {
      const accountId = 'user-account-123';
      expect(
        await service.getDecision(accountId, localProfileId: 'invitado'),
        GuestMigrationDecision.pending,
      );

      await service.rememberDecision(
        accountId,
        GuestMigrationDecision.acceptedForPhase3,
        localProfileId: 'invitado',
      );

      expect(
        await service.getDecision(accountId, localProfileId: 'invitado'),
        GuestMigrationDecision.acceptedForPhase3,
      );
    });

    test('declined decision is remembered locally', () async {
      const accountId = 'user-account-456';
      await service.rememberDecision(
        accountId,
        GuestMigrationDecision.declined,
        localProfileId: 'invitado',
      );

      expect(
        await service.getDecision(accountId, localProfileId: 'invitado'),
        GuestMigrationDecision.declined,
      );
    });

    test('empty guest profile reports zero counts and no meaningful data', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();

      final summary = await service.inspect(localProfileId: 'invitado');
      expect(summary.favoriteCount, 0);
      expect(summary.progressCount, 0);
      expect(summary.recentCount, 0);
      expect(summary.hasMeaningfulData, isFalse);
    });
  });
}
