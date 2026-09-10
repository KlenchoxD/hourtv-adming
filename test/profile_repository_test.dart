import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/hourtv_account_profile.dart';
import 'package:streamtv/services/profiles/local_guest_profile_repository.dart';
import 'package:streamtv/services/profiles/supabase_profile_repository.dart';
import 'package:streamtv/services/storage_service.dart';

class FakeProfilesApi {
  FakeProfilesApi({
    this.shouldThrowLimit = false,
    List<Map<String, dynamic>> initialRows = const [],
  }) : _rows = List.of(initialRows);

  final bool shouldThrowLimit;
  final List<Map<String, dynamic>> _rows;
  Map<String, dynamic>? lastInserted;

  Future<List<Map<String, dynamic>>> select(String ownerId) async {
    return _rows.where((r) => r['owner_id'] == ownerId).toList();
  }

  Future<Map<String, dynamic>> insert(Map<String, dynamic> row) async {
    if (shouldThrowLimit || _rows.where((r) => r['owner_id'] == row['owner_id']).length >= 5) {
      throw Exception('PostgreSQL error 23514: profile_limit_exceeded');
    }
    lastInserted = Map.of(row);
    final inserted = Map<String, dynamic>.from(row);
    inserted['id'] = 'gen-uuid-${_rows.length}';
    inserted['created_at'] = DateTime.now().toIso8601String();
    inserted['updated_at'] = DateTime.now().toIso8601String();
    _rows.add(inserted);
    return inserted;
  }

  Future<Map<String, dynamic>> update(String id, String ownerId, Map<String, dynamic> updates) async {
    final index = _rows.indexWhere((r) => r['id'] == id && r['owner_id'] == ownerId);
    if (index == -1) throw Exception('Row not found');
    final current = Map<String, dynamic>.from(_rows[index]);
    current.addAll(updates);
    current['updated_at'] = DateTime.now().toIso8601String();
    _rows[index] = current;
    return current;
  }

  Future<void> delete(String id, String ownerId) async {
    _rows.removeWhere((r) => r['id'] == id && r['owner_id'] == ownerId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseProfileRepository', () {
    const ownerId = '00000000-0000-0000-0000-000000000001';

    test('refuses operations without authenticated user', () async {
      final api = FakeProfilesApi();
      final repository = SupabaseProfileRepository(
        api: api,
        currentUserId: () => null,
      );

      await expectLater(
        repository.list(),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.create(const ProfileDraft(name: 'Test', avatarId: 'adult_1')),
        throwsA(isA<StateError>()),
      );
    });

    test('writes owner_id from authenticated user and orders by position', () async {
      final api = FakeProfilesApi(initialRows: [
        {
          'id': 'p-2',
          'owner_id': ownerId,
          'name': 'Segundo',
          'avatar_id': 'adult_2',
          'is_kids': false,
          'position': 1,
        },
        {
          'id': 'p-1',
          'owner_id': ownerId,
          'name': 'Primero',
          'avatar_id': 'adult_1',
          'is_kids': false,
          'position': 0,
        },
      ]);
      final repository = SupabaseProfileRepository(
        api: api,
        currentUserId: () => ownerId,
      );

      final list = await repository.list();
      expect(list.length, 2);
      expect(list[0].name, 'Primero');
      expect(list[0].position, 0);
      expect(list[1].name, 'Segundo');
      expect(list[1].position, 1);

      await repository.create(const ProfileDraft(name: 'Tercero', avatarId: 'adult_3'));
      expect(api.lastInserted?['owner_id'], ownerId);
      expect(api.lastInserted?['position'], 2);
    });

    test('translates database profile limit violation to ProfileLimitException', () async {
      final api = FakeProfilesApi(shouldThrowLimit: true);
      final repository = SupabaseProfileRepository(
        api: api,
        currentUserId: () => ownerId,
      );

      await expectLater(
        repository.create(const ProfileDraft(name: 'Over limit', avatarId: 'adult_1')),
        throwsA(isA<ProfileLimitException>()),
      );
    });
  });

  group('LocalGuestProfileRepository', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });

    test('round-trips profiles in guest mode and enforces 5-profile limit', () async {
      final repository = LocalGuestProfileRepository();

      expect(await repository.list(), isEmpty);

      // Create 5 profiles
      for (var i = 0; i < 5; i++) {
        final profile = await repository.create(ProfileDraft(
          name: 'Invitado $i',
          avatarId: 'adult_${i + 1}',
          isKids: i.isOdd,
        ));
        expect(profile.name, 'Invitado $i');
        expect(profile.position, i);
      }

      final list = await repository.list();
      expect(list.length, 5);

      // 6th profile must fail
      await expectLater(
        repository.create(const ProfileDraft(name: 'Sexto', avatarId: 'adult_1')),
        throwsA(isA<ProfileLimitException>()),
      );

      // Update
      final updated = await repository.update(list.first.copyWith(name: 'Renombrado'));
      expect(updated.name, 'Renombrado');
      final reloaded = await repository.list();
      expect(reloaded.first.name, 'Renombrado');

      // Delete
      await repository.delete(list.first.id);
      final remaining = await repository.list();
      expect(remaining.length, 4);
    });
  });
}
