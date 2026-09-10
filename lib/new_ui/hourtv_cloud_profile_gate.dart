import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hourtv_account_profile.dart';
import '../services/content_store.dart';
import '../services/migration/guest_migration_service.dart';
import '../services/parental_control_service.dart';
import '../services/profiles/profile_repository.dart';
import '../services/storage_service.dart';
import 'hourtv_guest_import_prompt.dart';
import 'hourtv_parental_gate.dart';
import 'hourtv_profile_avatar.dart';
import 'hourtv_profile_avatars.dart';

const _bg = Color(0xFF050505);
const _surface = Color(0xFF111113);
const _line = Color(0xFF29292E);
const _muted = Color(0xFFA6A6B0);
const _emerald = Color(0xFF00C781);

enum _CloudGateStep { list, type, avatar, name }

class HourTvCloudProfileGate extends StatefulWidget {
  const HourTvCloudProfileGate({
    super.key,
    required this.repository,
    this.migrationService,
    this.accountId,
    this.onProfileSelected,
    this.onSignOut,
  });

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
      final ownerId = widget.accountId ?? (list.isNotEmpty ? list.first.ownerId : null);
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
        _isLoading = false;
        _guestSummary = guestSummary;
        _showMigrationPrompt = showMigrationPrompt;
        _step = list.isEmpty ? _CloudGateStep.type : _CloudGateStep.list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar tus perfiles. Verifica tu conexión.';
        _isLoading = false;
      });
    }
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
    widget.onProfileSelected?.call(profile);
  }

  Future<void> _selectProfile(HourTvAccountProfile profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (profile.isKids && !await _ensureKidsRestricted()) return;
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
      if (_isKids && !await _ensureKidsRestricted()) return;
      final created = await widget.repository.create(ProfileDraft(
        name: name,
        avatarId: avatarId,
        isKids: _isKids,
      ));
      await _activateProfile(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _ensureKidsRestricted() async {
    if (ParentalControlService.isEnabled) return true;
    if (!ParentalControlService.hasPin) {
      final pins = await requestNewParentalPin(
        context,
        title: 'Crear PIN para el perfil infantil',
      );
      if (pins == null || !mounted) return false;
      if (pins.$1 != pins.$2) {
        _message('Los PIN no coinciden.');
        return false;
      }
      try {
        await ParentalControlService.enable(pins.$1);
      } on ArgumentError {
        _message('El PIN debe contener entre 4 y 6 dígitos.');
        return false;
      }
    } else {
      await StorageService.saveSetting(ParentalControlService.enabledKey, true);
    }
    await StorageService.saveSetting('kidsAutoRestricted', true);
    ContentStore.instance.refreshParentalFilter();
    return true;
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _emerald),
        ),
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
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: switch (_step) {
                _CloudGateStep.list => _listStep(),
                _CloudGateStep.type => _typeStep(),
                _CloudGateStep.avatar => _avatarStep(),
                _CloudGateStep.name => _nameStep(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String title, String subtitle, {VoidCallback? onBack}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _busy ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _listStep() {
    final canAdd = _profiles.length < 5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header('¿QUIÉN VE HOURTV?', 'Elige tu perfil para continuar'),
        if (_showMigrationPrompt && _guestSummary != null) ...[
          HourTvGuestImportPrompt(
            summary: _guestSummary!,
            onDecision: (decision) async {
              final migration =
                  widget.migrationService ?? GuestMigrationService();
              final ownerId = widget.accountId ??
                  (_profiles.isNotEmpty ? _profiles.first.ownerId : null);
              if (ownerId != null) {
                await migration.rememberDecision(ownerId, decision);
              }
              if (mounted) {
                setState(() => _showMigrationPrompt = false);
              }
            },
          ),
          const SizedBox(height: 24),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            for (final profile in _profiles)
              SizedBox(
                width: 130,
                child: _avatarCard(
                  seed: HourTvAvatarCatalog.seedFor(profile.avatarId),
                  label: profile.name,
                  onTap: () => unawaited(_selectProfile(profile)),
                ),
              ),
            if (canAdd)
              SizedBox(
                width: 130,
                child: _addProfileCard(),
              ),
          ],
        ),
        if (!canAdd) ...[
          const SizedBox(height: 24),
          const Text(
            'Máximo de 5 perfiles',
            style: TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
        if (widget.onSignOut != null) ...[
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white54),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _addProfileCard() {
    return Opacity(
      opacity: _busy ? .5 : 1,
      child: InkWell(
        onTap: _busy ? null : _goToType,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.transparent,
                child: Icon(Icons.add_rounded, color: _muted, size: 36),
              ),
              SizedBox(height: 10),
              Text(
                'AGREGAR PERFIL',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeStep() {
    final canGoBack = _profiles.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(
          'TIPO DE PERFIL',
          'Elige el tipo para empezar',
          onBack: canGoBack ? () => setState(() => _step = _CloudGateStep.list) : null,
        ),
        Row(
          children: [
            Expanded(
              child: _choiceCard(
                icon: Icons.person_rounded,
                label: 'Perfil normal',
                description: 'Acceso completo al catálogo',
                onTap: () => _pickType(false),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _choiceCard(
                icon: Icons.child_care_rounded,
                label: 'Perfil infantil',
                description: 'Contenido filtrado con PIN',
                onTap: () => _pickType(true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _choiceCard({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _emerald, size: 34),
            const SizedBox(height: 12),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarStep() {
    final options = _isKids ? HourTvAvatarCatalog.kids : HourTvAvatarCatalog.adults;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(
          'ELIGE TU AVATAR',
          _isKids ? 'Para el perfil infantil' : 'Opciones para elegir',
          onBack: _goToType,
        ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            for (final option in options)
              SizedBox(
                width: 130,
                child: _avatarCard(
                  seed: option.seed,
                  label: option.label,
                  onTap: () => _pickAvatar(option.id),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _avatarCard({
    required String seed,
    required String label,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: _busy ? .5 : 1,
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HourTvProfileAvatar(
                profileName: label,
                avatarSeed: seed,
                radius: 36,
                backgroundColor: _emerald,
              ),
              const SizedBox(height: 10),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameStep() {
    final avatarId = _avatarId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(
          'PONLE UN NOMBRE',
          'Así vas a identificar este perfil',
          onBack: () => setState(() => _step = _CloudGateStep.avatar),
        ),
        if (avatarId != null)
          HourTvProfileAvatar(
            profileName: _nameController.text,
            avatarSeed: HourTvAvatarCatalog.seedFor(avatarId),
            radius: 44,
            backgroundColor: _emerald,
          ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => unawaited(_createProfile()),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nombre del perfil',
            hintStyle: const TextStyle(color: _muted),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _emerald, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty || _busy
              ? null
              : () => unawaited(_createProfile()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _emerald,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
