import '../../models/hourtv_account_profile.dart';

abstract interface class ProfileRepository {
  Future<List<HourTvAccountProfile>> list();
  Future<HourTvAccountProfile> create(ProfileDraft draft);
  Future<HourTvAccountProfile> update(HourTvAccountProfile profile);
  Future<void> delete(String profileId);
}
