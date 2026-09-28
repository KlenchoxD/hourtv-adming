import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/hourtv_account_profile.dart';
import 'package:streamtv/new_ui/hourtv_cloud_profile_gate.dart';
import 'package:streamtv/new_ui/hourtv_profile_avatars.dart';
import 'package:streamtv/services/profiles/profile_repository.dart';
import 'package:streamtv/services/storage_service.dart';

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    List<HourTvAccountProfile> initialProfiles = const [],
    this.shouldFail = false,
  }) : _profiles = List.of(initialProfiles);

  factory FakeProfileRepository.withCount(int count) {
    return FakeProfileRepository(
      initialProfiles: List.generate(
        count,
        (i) => HourTvAccountProfile(
          id: 'cloud-p-$i',
          ownerId: 'owner-1',
          name: 'Perfil ${i + 1}',
          avatarId: 'adult_${(i % 6) + 1}',
          isKids: false,
          position: i,
        ),
      ),
    );
  }

  factory FakeProfileRepository.failing() {
    return FakeProfileRepository(shouldFail: true);
  }

  final bool shouldFail;
  final List<HourTvAccountProfile> _profiles;
  int createCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<HourTvAccountProfile>> list() async {
    if (shouldFail) throw Exception('Network error listing profiles');
    return List.of(_profiles);
  }

  @override
  Future<HourTvAccountProfile> create(ProfileDraft draft) async {
    if (shouldFail) throw Exception('Network error creating profile');
    if (_profiles.length >= 5) throw const ProfileLimitException();
    createCalls++;
    final profile = HourTvAccountProfile(
      id: 'cloud-p-${_profiles.length}',
      ownerId: 'owner-1',
      name: draft.name.trim(),
      avatarId: draft.avatarId.trim(),
      isKids: draft.isKids,
      position: _profiles.length,
    );
    _profiles.add(profile);
    return profile;
  }

  @override
  Future<HourTvAccountProfile> update(HourTvAccountProfile profile) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      _profiles[index] = profile;
    }
    return profile;
  }

  @override
  Future<void> delete(String profileId) async {
    deleteCalls++;
    _profiles.removeWhere((p) => p.id == profileId);
  }
}

Widget testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('HourTvCloudProfileGate', () {
    testWidgets('fifth cloud profile removes add action', (tester) async {
      final repository = FakeProfileRepository.withCount(5);
      await tester.pumpWidget(testApp(HourTvCloudProfileGate(
        repository: repository,
        onProfileSelected: (_) {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Agregar perfil'), findsNothing);
      expect(find.text('Máximo de 5 perfiles'), findsOneWidget);
    });

    testWidgets('repository failure offers retry and sign out', (tester) async {
      final repository = FakeProfileRepository.failing();
      bool signedOut = false;

      await tester.pumpWidget(testApp(HourTvCloudProfileGate(
        repository: repository,
        onProfileSelected: (_) {},
        onSignOut: () => signedOut = true,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(signedOut, isTrue);
    });

    testWidgets('selecting profile persists cloud profile context and notifies', (tester) async {
      final repository = FakeProfileRepository.withCount(2);
      HourTvAccountProfile? selected;

      await tester.pumpWidget(testApp(HourTvCloudProfileGate(
        repository: repository,
        onProfileSelected: (p) => selected = p,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Perfil 1'), findsOneWidget);
      await tester.tap(find.text('Perfil 1'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.id, 'cloud-p-0');
      expect(StorageService.cloudProfileId, 'cloud-p-0');
      expect(StorageService.hasChosenProfile.value, isTrue);
    });

    testWidgets('empty cloud profiles opens wizard immediately and allows creating profile', (tester) async {
      final repository = FakeProfileRepository.withCount(0);
      HourTvAccountProfile? selected;

      await tester.pumpWidget(testApp(HourTvCloudProfileGate(
        repository: repository,
        onProfileSelected: (p) => selected = p,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo perfil'), findsOneWidget);
      await tester.tap(find.text('Perfil normal'));
      await tester.pumpAndSettle();

      expect(find.text('Elige un avatar'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('avatar-${HourTvAvatarCatalog.adults.first.id}')));
      await tester.pumpAndSettle();

      expect(find.text('¿Cómo se llama?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Nuevo Perfil');
      await tester.pump();

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(selected, isNotNull);
      expect(selected!.name, 'Nuevo Perfil');
      expect(StorageService.cloudProfileId, isNotNull);
      expect(StorageService.hasChosenProfile.value, isTrue);
    });

    testWidgets('clearing cloud profile context resets active profile', (tester) async {
      await StorageService.setCloudProfileContext(
        accountId: 'acc-1',
        profileId: 'prof-1',
        name: 'Test Profile',
        avatarId: 'adult_1',
        isKids: false,
      );
      expect(StorageService.cloudAccountId, 'acc-1');
      expect(StorageService.cloudProfileId, 'prof-1');

      await StorageService.clearCloudProfileContext();
      expect(StorageService.cloudAccountId, isNull);
      expect(StorageService.cloudProfileId, isNull);
      expect(StorageService.hasChosenProfile.value, isFalse);
    });
  });

  group('Traer perfiles del teléfono a una cuenta nueva', () {
    testWidgets('los sube con sus datos y no vuelve a ofrecerlo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      await StorageService.createProfile(
        name: 'Kleiner',
        avatarId: 'adult_2',
        isKids: false,
      );
      final local = StorageService.loadProfiles().single;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'recent_channels.profile.${local['id']}',
        '[{"name":"Coco","url":"https://x/movie/coco.mp4"}]',
      );
      await prefs.setStringList(
        'liked_channels.profile.${local['id']}',
        ['https://x/movie/coco.mp4'],
      );

      final repository = FakeProfileRepository.withCount(0);
      await tester.pumpWidget(testApp(HourTvCloudProfileGate(
        repository: repository,
        accountId: 'owner-1',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Trae tus perfiles'), findsOneWidget);
      expect(find.text('Kleiner'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import_local_profiles_button')));
      await tester.pumpAndSettle();

      // Quedó en la cuenta y listo para elegir.
      expect(repository.createCalls, 1);
      expect(find.text('¿Quién está viendo?'), findsOneWidget);
      expect(find.text('Kleiner'), findsOneWidget);
      // Sus datos se copiaron al perfil de la nube (el local sigue igual).
      expect(
        prefs.getString('recent_channels.profile.cloud-p-0'),
        contains('Coco'),
      );
      expect(
        prefs.getStringList('liked_channels.profile.cloud-p-0'),
        ['https://x/movie/coco.mp4'],
      );
      expect(
        prefs.getString('recent_channels.profile.${local['id']}'),
        contains('Coco'),
      );

      // Otra vez con la cuenta vacía (p. ej. borró los perfiles): ya no insiste.
      await tester.pumpWidget(testApp(HourTvCloudProfileGate(
        key: UniqueKey(),
        repository: FakeProfileRepository.withCount(0),
        accountId: 'owner-1',
      )));
      await tester.pumpAndSettle();
      expect(find.text('Trae tus perfiles'), findsNothing);
      expect(find.text('Nuevo perfil'), findsOneWidget);
    });
  });
}
