import '../../models/hourtv_account_profile.dart';
import '../storage_service.dart';
import 'profile_repository.dart';

class LocalGuestProfileRepository implements ProfileRepository {
  const LocalGuestProfileRepository();

  static const String guestOwnerId = 'local_guest';

  @override
  Future<List<HourTvAccountProfile>> list() async {
    final rawList = StorageService.loadProfiles();
    final result = <HourTvAccountProfile>[];
    for (var i = 0; i < rawList.length; i++) {
      final p = rawList[i];
      result.add(HourTvAccountProfile(
        id: p['id']?.toString() ?? '',
        ownerId: guestOwnerId,
        name: p['name']?.toString() ?? '',
        avatarId: p['avatarId']?.toString() ?? '',
        isKids: p['isKids'] == true,
        position: i,
      ));
    }
    return result;
  }

  @override
  Future<HourTvAccountProfile> create(ProfileDraft draft) async {
    final existing = await list();
    if (existing.length >= 5) {
      throw const ProfileLimitException();
    }

    final record = await StorageService.createProfile(
      name: draft.name.trim(),
      avatarId: draft.avatarId.trim(),
      isKids: draft.isKids,
    );

    return HourTvAccountProfile(
      id: record['id']?.toString() ?? '',
      ownerId: guestOwnerId,
      name: record['name']?.toString() ?? '',
      avatarId: record['avatarId']?.toString() ?? '',
      isKids: record['isKids'] == true,
      position: existing.length,
    );
  }

  @override
  Future<HourTvAccountProfile> update(HourTvAccountProfile profile) async {
    final ok = await StorageService.updateProfile(
      id: profile.id,
      name: profile.name.trim(),
      avatarId: profile.avatarId.trim(),
      isKids: profile.isKids,
    );
    if (!ok) {
      throw StateError('Perfil no encontrado para actualizar.');
    }
    return profile;
  }

  @override
  Future<void> delete(String profileId) async {
    await StorageService.deleteProfile(profileId);
  }
}
