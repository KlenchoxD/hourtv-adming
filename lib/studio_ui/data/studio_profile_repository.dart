import '../../services/storage_service.dart';
import 'studio_profile.dart';

class StudioProfileRepository {
  static const profilesKey = 'studio_profiles_v1';
  static const activeProfileKey = 'studio_active_profile_v1';

  List<StudioProfile> loadProfiles() {
    final raw = StorageService.getSetting(
      profilesKey,
      defaultValue: const <dynamic>[],
    );
    if (raw is! List) return const <StudioProfile>[];

    return raw
        .whereType<Map>()
        .map(
          (value) => StudioProfile.fromJson(Map<String, dynamic>.from(value)),
        )
        .where((profile) => profile.id.isNotEmpty && profile.name.isNotEmpty)
        .toList(growable: false);
  }

  StudioProfile? loadActiveProfile() {
    final profiles = loadProfiles();
    if (profiles.isEmpty) return null;
    final activeId = StorageService.getSetting(activeProfileKey)?.toString();
    for (final profile in profiles) {
      if (profile.id == activeId) return profile;
    }
    return profiles.first;
  }

  bool get requiresProfileCreation => loadProfiles().isEmpty;

  Future<void> saveProfiles(
    List<StudioProfile> profiles, {
    String? activeId,
  }) async {
    final unique = <String, StudioProfile>{
      for (final profile in profiles) profile.id: profile,
    }.values.toList(growable: false);
    await StorageService.saveSetting(
      profilesKey,
      unique.map((profile) => profile.toJson()).toList(growable: false),
    );

    final currentId =
        activeId ?? StorageService.getSetting(activeProfileKey)?.toString();
    final resolvedId = unique.any((profile) => profile.id == currentId)
        ? currentId
        : unique.firstOrNull?.id;
    await StorageService.saveSetting(activeProfileKey, resolvedId ?? '');
  }

  Future<void> createProfile(StudioProfile profile) async {
    final profiles = <StudioProfile>[...loadProfiles(), profile];
    await saveProfiles(profiles, activeId: profile.id);
  }

  Future<void> updateProfile(StudioProfile profile) async {
    final profiles = loadProfiles();
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) return;
    final updated = <StudioProfile>[...profiles]..[index] = profile;
    await saveProfiles(updated);
  }

  Future<void> deleteProfile(String profileId) async {
    final profiles = loadProfiles()
        .where((profile) => profile.id != profileId)
        .toList(growable: false);
    final current = loadActiveProfile();
    final activeId = current?.id == profileId
        ? profiles.firstOrNull?.id
        : current?.id;
    await saveProfiles(profiles, activeId: activeId);
  }

  Future<void> selectProfile(String profileId) async {
    if (!loadProfiles().any((profile) => profile.id == profileId)) return;
    await StorageService.saveSetting(activeProfileKey, profileId);
  }
}
