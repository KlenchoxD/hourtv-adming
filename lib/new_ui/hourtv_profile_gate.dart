import 'dart:async';

import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/storage_service.dart';
import 'hourtv_profile_avatars.dart';
import 'hourtv_profile_picker.dart';

const _bg = Color(0xFF050505);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: switch (_step) {
          _GateStep.list => _listStep(),
          _GateStep.type => _typeStep(),
          _GateStep.avatar => _avatarStep(),
          _GateStep.name => _nameStep(),
        },
      ),
    );
  }

  Widget _typeStep() => HourTvProfileStep(
    title: 'Nuevo perfil',
    subtitle: '¿Para quién es este perfil?',
    onBack: _profiles.isNotEmpty ? () => setState(() => _step = _GateStep.list) : null,
    child: HourTvProfileTypeChoice(onPick: _pickType),
  );

  Widget _avatarStep() => HourTvProfileStep(
    title: 'Elige un avatar',
    subtitle: _isKids
        ? 'Para el perfil infantil'
        : 'Toca el que más te guste',
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
    onBack: _busy ? null : () => setState(() => _step = _GateStep.avatar),
    child: HourTvProfileNameForm(
      avatarSeed: _avatarId == null
          ? null
          : HourTvAvatarCatalog.seedFor(_avatarId!),
      controller: _nameController,
      buttonLabel: 'Crear perfil',
      kids: _isKids,
      busy: _busy,
      onChanged: () => setState(() {}),
      onSubmit: () => unawaited(_createProfile()),
    ),
  );

  Widget _listStep() => HourTvProfilePicker(
    busy: _busy,
    onAdd: _goToType,
    profiles: [
      for (final profile in _profiles)
        HourTvProfilePickerItem(
          name: profile['name'].toString(),
          avatarSeed: HourTvAvatarCatalog.seedFor(
            profile['avatarId'].toString(),
          ),
          isKids: profile['isKids'] == true,
          onTap: () => unawaited(_enterExisting(profile)),
        ),
    ],
  );

}
