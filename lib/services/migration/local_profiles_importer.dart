import 'dart:async';

import '../../models/hourtv_account_profile.dart';
import '../profiles/profile_repository.dart';
import '../storage_service.dart';
import '../sync/profile_cloud_sync.dart';

/// Lleva a una cuenta nueva los perfiles creados en este teléfono sin cuenta
/// (nombre, avatar, si es infantil) junto con sus datos: favoritos, "Me
/// gusta", "Continuar viendo" e historial. Antes, al iniciar sesión por
/// primera vez, esos perfiles no aparecían y había que empezar de cero.
///
/// Los datos se copian (no se mueven): los perfiles locales siguen intactos
/// para "Continuar sin cuenta".
class LocalProfilesImporter {
  LocalProfilesImporter({required this.repository});

  final ProfileRepository repository;

  /// Límite de perfiles por cuenta en la nube.
  static const maxCloudProfiles = 5;

  static String _doneKey(String accountId) =>
      'localProfilesImportDecision.$accountId';

  /// Perfiles de este teléfono que se pueden traer.
  List<Map<String, dynamic>> get localProfiles => StorageService.loadProfiles()
      .where((p) => (p['name']?.toString().trim() ?? '').isNotEmpty)
      .toList(growable: false);

  /// Se ofrece una sola vez por cuenta, y solo si la cuenta está vacía.
  bool shouldOffer(String accountId, List<HourTvAccountProfile> cloud) =>
      cloud.isEmpty &&
      localProfiles.isNotEmpty &&
      StorageService.getSetting(_doneKey(accountId)) == null;

  Future<void> dismiss(String accountId) =>
      StorageService.saveSetting(_doneKey(accountId), 'declined');

  /// Crea los perfiles en la cuenta y copia sus datos. Devuelve los creados.
  Future<List<HourTvAccountProfile>> importAll(String accountId) async {
    final created = <HourTvAccountProfile>[];
    for (final local in localProfiles.take(maxCloudProfiles)) {
      final profile = await repository.create(
        ProfileDraft(
          name: local['name'].toString().trim(),
          avatarId: local['avatarId']?.toString() ?? '',
          isKids: local['isKids'] == true,
        ),
      );
      await StorageService.copyProfileData(
        fromProfileId: local['id'].toString(),
        toProfileId: profile.id,
      );
      // El historial y el avance de la base local (de ahí salen las
      // recomendaciones) se copian en la primera sincronización del perfil.
      await ProfileCloudSync.rememberImportSource(
        cloudProfileId: profile.id,
        localProfileId: local['id'].toString(),
      );
      created.add(profile);
      // Sube sus favoritos y avance para verlos en cualquier equipo.
      unawaited(ProfileCloudSync.sync(profile.id));
    }
    await StorageService.saveSetting(_doneKey(accountId), 'imported');
    return created;
  }
}
