import 'package:flutter/material.dart';
import 'package:streamtv/hybrid_mobile/data/hybrid_catalog_controller.dart';
import 'package:streamtv/hybrid_mobile/theme/hybrid_mobile_theme.dart';
import 'package:streamtv/studio_ui/data/studio_media_item.dart';
import 'package:streamtv/studio_ui/data/studio_profile.dart';
import 'package:streamtv/studio_ui/data/studio_profile_repository.dart';

class HybridTestApp extends StatelessWidget {
  const HybridTestApp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: HybridMobileTheme.dark(),
    home: child,
  );
}

class InMemoryHybridProfileRepository implements StudioProfileStore {
  InMemoryHybridProfileRepository({
    List<StudioProfile> profiles = const <StudioProfile>[],
    String? activeId,
  }) : _profiles = <StudioProfile>[...profiles],
       _activeId = activeId ?? profiles.firstOrNull?.id;

  List<StudioProfile> _profiles;
  String? _activeId;

  @override
  List<StudioProfile> loadProfiles() => List<StudioProfile>.unmodifiable(_profiles);

  @override
  StudioProfile? loadActiveProfile() {
    for (final profile in _profiles) {
      if (profile.id == _activeId) return profile;
    }
    return _profiles.firstOrNull;
  }

  @override
  bool get requiresProfileCreation => _profiles.isEmpty;

  @override
  Future<void> saveProfiles(
    List<StudioProfile> profiles, {
    String? activeId,
  }) async {
    _profiles = <StudioProfile>[...profiles];
    _activeId = activeId ?? _profiles.firstOrNull?.id;
  }

  @override
  Future<void> createProfile(StudioProfile profile) async {
    _profiles = <StudioProfile>[..._profiles, profile];
    _activeId = profile.id;
  }

  @override
  Future<void> updateProfile(StudioProfile profile) async {
    final index = _profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) return;
    _profiles = <StudioProfile>[..._profiles]..[index] = profile;
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    _profiles = _profiles
        .where((profile) => profile.id != profileId)
        .toList(growable: false);
    if (_activeId == profileId) _activeId = _profiles.firstOrNull?.id;
  }

  @override
  Future<void> selectProfile(String profileId) async {
    if (_profiles.any((profile) => profile.id == profileId)) {
      _activeId = profileId;
    }
  }
}

class EmptyHybridCatalogSource extends ChangeNotifier
    implements HybridCatalogSource {
  @override
  Future<void> ensureLoaded() async {}

  @override
  List<StudioMediaItem> snapshot() => const <StudioMediaItem>[];

  @override
  Future<bool> toggleMyList(StudioMediaItem item) async => false;
}
