import 'dart:async';

import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/parental_control_service.dart';
import '../services/storage_service.dart';
import 'hourtv_parental_gate.dart';
import 'hourtv_profile_avatar.dart';
import 'hourtv_profile_avatars.dart';

const _bg = Color(0xFF050505);
const _surface = Color(0xFF111113);
const _line = Color(0xFF29292E);
const _muted = Color(0xFFA6A6B0);
const _emerald = Color(0xFF00C781);

enum _GateStep { list, type, avatar, name }

/// Pantalla obligatoria antes de entrar a la app: ni al instalar por primera
/// vez ni tras "Cerrar sesión" hay forma de saltarsela. La primera vez no
/// hay perfiles guardados, asi que va directo a crear uno (sin presets que
/// elegir); despues, muestra los perfiles ya creados mas la opcion de
/// agregar otro, igual que el selector de Netflix.
class HourTvProfileGate extends StatefulWidget {
  const HourTvProfileGate({super.key});

  @override
  State<HourTvProfileGate> createState() => _HourTvProfileGateState();
}

class _HourTvProfileGateState extends State<HourTvProfileGate> {
  late final _profiles = StorageService.loadProfiles();
  late var _step = _profiles.isEmpty ? _GateStep.type : _GateStep.list;
  var _isKids = false;
  String? _avatarId;
  var _busy = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _goToType() => setState(() {
    _isKids = false;
    _avatarId = null;
    _step = _GateStep.type;
  });

  void _pickType(bool isKids) => setState(() {
    _isKids = isKids;
    _step = _GateStep.avatar;
  });

  void _pickAvatar(String avatarId) => setState(() {
    _avatarId = avatarId;
    _step = _GateStep.name;
  });

  Future<void> _enterExisting(Map<String, dynamic> profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (profile['isKids'] == true && !await _ensureKidsRestricted()) return;
      await StorageService.setActiveProfileById(profile['id'].toString());
      await StorageService.markProfileChosen();
      ContentStore.instance.refreshProfileData();
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
      await StorageService.createProfile(
        name: name,
        avatarId: avatarId,
        isKids: _isKids,
      );
      await StorageService.markProfileChosen();
      ContentStore.instance.refreshProfileData();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mismo flujo que en el hub de Perfil: un perfil Kids exige PIN
  /// (creandolo la primera vez) para que el filtro realmente se aplique.
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // Antes envolvia todo en Center(): con pocas tarjetas (el paso "tipo
      // de perfil" solo tiene 2) eso dejaba tanto espacio arriba como abajo,
      // como si algo faltara. Alineado arriba, el contenido empieza donde el
      // ojo lo espera sin importar cuanto ocupe cada paso.
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: switch (_step) {
                _GateStep.list => _listStep(),
                _GateStep.type => _typeStep(),
                _GateStep.avatar => _avatarStep(),
                _GateStep.name => _nameStep(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header('¿QUIÉN VE HOURTV?', 'Elige tu perfil para continuar'),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            for (final profile in _profiles)
              SizedBox(
                width: 130,
                child: _avatarCard(
                  seed: HourTvAvatarCatalog.seedFor(
                    profile['avatarId'].toString(),
                  ),
                  label: profile['name'].toString(),
                  onTap: () => unawaited(_enterExisting(profile)),
                ),
              ),
            SizedBox(
              width: 130,
              child: _addProfileCard(),
            ),
          ],
        ),
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
            border: Border.all(color: _line, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: Colors.transparent,
                child: Icon(Icons.add_rounded, color: _muted, size: 36),
              ),
              const SizedBox(height: 10),
              const Text(
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
          'CREAR PERFIL',
          'Todavía no existe: elige el tipo para empezar',
          onBack: canGoBack
              ? () => setState(() => _step = _GateStep.list)
              : null,
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
    final options = _isKids
        ? HourTvAvatarCatalog.kids
        : HourTvAvatarCatalog.adults;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(
          'ELIGE UNA CARICATURA',
          _isKids
              ? 'Para el perfil infantil'
              : 'Al menos 6 opciones para elegir',
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
          onBack: () => setState(() => _step = _GateStep.avatar),
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
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _emerald),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _busy || _nameController.text.trim().isEmpty
                ? null
                : () => unawaited(_createProfile()),
            style: FilledButton.styleFrom(
              backgroundColor: _emerald,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'CREAR PERFIL',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
