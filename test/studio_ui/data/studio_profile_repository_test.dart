import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/studio_ui/data/studio_profile.dart';
import 'package:streamtv/studio_ui/data/studio_profile_repository.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
  });

  test('persists profiles and restores the active profile', () async {
    final repository = StudioProfileRepository();
    const profile = StudioProfile(
      id: 'renata',
      name: 'Renata',
      avatarKey: 'emerald',
    );

    await repository.saveProfiles(<StudioProfile>[
      profile,
    ], activeId: profile.id);

    expect(repository.loadProfiles(), <StudioProfile>[profile]);
    expect(repository.loadActiveProfile(), profile);
    expect(repository.requiresProfileCreation, isFalse);
  });

  test(
    'deleting the active profile selects the next available profile',
    () async {
      final repository = StudioProfileRepository();
      const renata = StudioProfile(
        id: 'renata',
        name: 'Renata',
        avatarKey: 'emerald',
      );
      const invitado = StudioProfile(
        id: 'invitado',
        name: 'Invitado',
        avatarKey: 'violet',
      );
      await repository.saveProfiles(const <StudioProfile>[
        renata,
        invitado,
      ], activeId: renata.id);

      await repository.deleteProfile(renata.id);

      expect(repository.loadProfiles(), const <StudioProfile>[invitado]);
      expect(repository.loadActiveProfile(), invitado);
    },
  );
}
