import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/hourtv_account_profile.dart';

void main() {
  group('HourTvAccountProfile', () {
    test('profile model round-trips database rows', () {
      final profileRow = {
        'id': 'b1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
        'owner_id': '00000000-0000-0000-0000-000000000001',
        'name': 'Principal',
        'avatar_id': 'adult_1',
        'is_kids': false,
        'position': 0,
        'created_at': '2026-09-09T00:00:00.000Z',
        'updated_at': '2026-09-09T00:00:00.000Z',
      };
      final profile = HourTvAccountProfile.fromJson(profileRow);
      expect(profile.id, 'b1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
      expect(profile.ownerId, '00000000-0000-0000-0000-000000000001');
      expect(profile.name, 'Principal');
      expect(profile.avatarId, 'adult_1');
      expect(profile.isKids, isFalse);
      expect(profile.position, 0);

      final insertJson = profile.toInsertJson();
      expect(insertJson, isNot(contains('id')));
      expect(insertJson['owner_id'], '00000000-0000-0000-0000-000000000001');
      expect(insertJson['name'], 'Principal');
      expect(insertJson['avatar_id'], 'adult_1');
      expect(insertJson['is_kids'], isFalse);
      expect(insertJson['position'], 0);
    });

    test('trims name and avatarId in toInsertJson', () {
      const profile = HourTvAccountProfile(
        id: '1',
        ownerId: 'owner-1',
        name: '  Trimmed Name  ',
        avatarId: '  avatar_1  ',
        isKids: true,
        position: 2,
      );
      final json = profile.toInsertJson();
      expect(json['name'], 'Trimmed Name');
      expect(json['avatar_id'], 'avatar_1');
      expect(json['is_kids'], isTrue);
      expect(json['position'], 2);
    });
  });
}
