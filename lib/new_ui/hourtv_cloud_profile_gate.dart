import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hourtv_account_profile.dart';
import '../services/content_store.dart';
import '../services/migration/guest_migration_service.dart';
import '../services/migration/local_profiles_importer.dart';
import '../services/profiles/profile_repository.dart';
import '../services/storage_service.dart';
import '../services/sync/profile_cloud_sync.dart';
import 'hourtv_guest_import_prompt.dart';
import 'hourtv_profile_avatars.dart';
import 'hourtv_profile_picker.dart';

const _bg = Color(0xFF050505);
const _muted = Color(0xFFA6A6B0);
const _emerald = Color(0xFF00C781);

enum _CloudGateStep { list, import, type, avatar, name }

class HourTvCloudProfileGate extends StatefulWidget {
  const HourTvCloudProfileGate({
    super.key,
    required this.repository,
    this.migrationService,
    this.accountId,
    this.onProfileSelected,
    this.onSignOut,
    this.localImporter,
  });

  /// Para pruebas; por defecto usa el repositorio de la cuenta.
  final LocalProfilesImporter? localImporter;

  final ProfileRepository repository;
  final GuestMigrationService? migrationService;
  final String? accountId;
  final ValueChanged<HourTvAccountProfile>? onProfileSelected;
  final VoidCallback? onSignOut;

  @override
  State<HourTvCloudProfileGate> createState() => _HourTvCloudProfileGateState();
}

class _HourTvCloudProfileGateState extends State<HourTvCloudProfileGate> {
  List<HourTvAccountProfile> _profiles = [];
  bool _isLoading = true;
  String? _errorMessage;
  var _step = _CloudGateStep.list;
  var _isKids = false;
  String? _avatarId;
  var _busy = false;
  final _nameController = TextEditingController();
  late final LocalProfilesImporter _importer =
      widget.localImporter ??
      LocalProfilesImporter(repository: widget.repository);
  String? _importError;
  GuestMigrationSummary? _guestSummary;
  bool _showMigrationPrompt = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.repository.list();
      if (!mounted) return;

      final migration = widget.migrationService ?? GuestMigrationService();
      final ownerId =
          widget.accountId ?? (list.isNotEmpty ? list.first.ownerId : null);
      GuestMigrationSummary? guestSummary;
      bool showMigrationPrompt = false;

      if (ownerId != null) {
        final decision = await migration.getDecision(ownerId);
        if (decision == GuestMigrationDecision.pending) {
          final summary = await migration.inspect();
          if (summary.hasMeaningfulData) {
            guestSummary = summary;
            showMigrationPrompt = true;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _profiles = list;
        unawaited(
          ProfileCloudSync.rememberAccountProfiles(list.map((p) => p.id)),
        );
        _isLoading = false;
        _guestSummary = guestSummary;
        _showMigrationPrompt = showMigrationPrompt;
        final accountId = widget.accountId;
        _step = list.isNotEmpty
            ? _CloudGateStep.list
            : accountId != null && _importer.shouldOffer(accountId, list)
            ? _CloudGateStep.import
            : _CloudGateStep.type;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudieron cargar tus perfiles. Verifica tu conexión.';
        _isLoading = false;
      });
    }
  }

  Future<void> _importLocalProfiles() async {
    final accountId = widget.accountId;
    if (accountId == null || _busy) return;
    setState(() {
      _busy = true;
      _importError = null;
    });
    try {
      final created = await _importer.importAll(accountId);
      if (!mounted) return;
      setState(() {
        _profiles = created;
        unawaited(
          ProfileCloudSync.rememberAccountProfiles(created.map((p) => p.id)),
        );
        _step = _CloudGateStep.list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _importError =
            'No se pudieron subir los perfiles. Revisa tu conexión e '
            'inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skipImport() async {
    final accountId = widget.accountId;
    if (accountId != null) await _importer.dismiss(accountId);
    if (mounted) _goToType();
  }

  void _goToType() => setState(() {
    _isKids = false;
    _avatarId = null;
    _step = _CloudGateStep.type;
  });

  void _pickType(bool isKids) => setState(() {
    _isKids = isKids;
    _step = _CloudGateStep.avatar;
  });

  void _pickAvatar(String avatarId) => setState(() {
    _avatarId = avatarId;
    _step = _CloudGateStep.name;
  });

  Future<void> _activateProfile(HourTvAccountProfile profile) async {
    await StorageService.setCloudProfileContext(
      accountId: profile.ownerId,
      profileId: profile.id,
      name: profile.name,
      avatarId: profile.avatarId,
      isKids: profile.isKids,
    );
    await StorageService.markProfileChosen();
    ContentStore.instance.refreshProfileData();
    // Trae lo que se hizo en otros equipos con este perfil.
    unawaited(
      ProfileCloudSync.sync(profile.id).then((changed) {
        if (changed) ContentStore.instance.refreshProfileData();
      }),
    );
    widget.onProfileSelected?.call(profile);
  }

  Future<void> _selectProfile(HourTvAccountProfile profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _activateProfile(profile);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    final avatarId = _avatarId;
    if (name.isEmpty || avatarId == null || _busy) return;
    setState(() => _busy = true);
    try {
      final created = await widget.repository.create(
        ProfileDraft(name: name, avatarId: avatarId, isKids: _isKids),
      );
      await _activateProfile(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _emerald)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadProfiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _emerald,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Reintentar'),
                ),
                const SizedBox(height: 12),
                if (widget.onSignOut != null)
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: switch (_step) {
          _CloudGateStep.list => _listStep(),
          _CloudGateStep.import => _importStep(),
          _CloudGateStep.type => _typeStep(),
          _CloudGateStep.avatar => _avatarStep(),
          _CloudGateStep.name => _nameStep(),
        },
      ),
    );
  }

  Widget _importStep() => HourTvProfileStep(
    title: 'Trae tus perfiles',
    subtitle:
        'Estos perfiles están en este teléfono. Súbelos a tu cuenta con sus '
        'favoritos y "Continuar viendo".',
    child: HourTvProfileImportChoice(
      profiles: [
        for (final p in _importer.localProfiles.take(
          LocalProfilesImporter.maxCloudProfiles,
        ))
          (
            name: p['name'].toString(),
            avatarSeed: HourTvAvatarCatalog.seedFor(
              p['avatarId']?.toString() ?? '',
            ),
            isKids: p['isKids'] == true,
          ),
      ],
      busy: _busy,
      error: _importError,
      onImport: () => unawaited(_importLocalProfiles()),
      onSkip: () => unawaited(_skipImport()),
    ),
  );

  Widget _typeStep() => HourTvProfileStep(
    title: 'Nuevo perfil',
    subtitle: '¿Para quién es este perfil?',
    onBack: _profiles.isNotEmpty
        ? () => setState(() => _step = _CloudGateStep.list)
        : null,
    child: HourTvProfileTypeChoice(onPick: _pickType),
  );

  Widget _avatarStep() => HourTvProfileStep(
    title: 'Elige un avatar',
    subtitle: _isKids ? 'Para el perfil infantil' : 'Toca el que más te guste',
    onBack: _busy ? null : _goToType,
    child: HourTvAvatarGrid(
      options: _isKids ? HourTvAvatarCatalog.kids : HourTvAvatarCatalog.adults,
      kids: _isKids,
      enabled: !_busy,
      onPick: _pickAvatar,
    ),
  );

  Widget _nameStep() => HourTvProfileStep(
    title: '¿Cómo se llama?',
    subtitle: 'Así vas a identificar este perfil',
    onBack: _busy ? null : () => setState(() => _step = _CloudGateStep.avatar),
    child: HourTvProfileNameForm(
      avatarSeed: _avatarId == null
          ? null
          : HourTvAvatarCatalog.seedFor(_avatarId!),
      controller: _nameController,
      buttonLabel: 'Guardar',
      kids: _isKids,
      busy: _busy,
      onChanged: () => setState(() {}),
      onSubmit: () => unawaited(_createProfile()),
    ),
  );

  Widget _listStep() {
    final canAdd = _profiles.length < 5;
    return HourTvProfilePicker(
      busy: _busy,
      onAdd: canAdd ? _goToType : null,
      header: _showMigrationPrompt && _guestSummary != null
          ? HourTvGuestImportPrompt(
              summary: _guestSummary!,
              onDecision: (decision) async {
                final migration =
                    widget.migrationService ?? GuestMigrationService();
                final ownerId =
                    widget.accountId ??
                    (_profiles.isNotEmpty ? _profiles.first.ownerId : null);
                if (ownerId != null) {
                  await migration.rememberDecision(ownerId, decision);
                }
                if (mounted) {
                  setState(() => _showMigrationPrompt = false);
                }
              },
            )
          : null,
      profiles: [
        for (final profile in _profiles)
          HourTvProfilePickerItem(
            name: profile.name,
            avatarSeed: HourTvAvatarCatalog.seedFor(profile.avatarId),
            isKids: profile.isKids,
            onTap: () => unawaited(_selectProfile(profile)),
          ),
      ],
      footer: [
        if (!canAdd) ...[
          const SizedBox(height: 24),
          const Text(
            'Máximo de 5 perfiles',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (widget.onSignOut != null) ...[
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(
              Icons.logout_rounded,
              size: 16,
              color: Colors.white54,
            ),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
