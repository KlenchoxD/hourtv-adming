import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/parental_control_service.dart';
import 'hourtv_parental_gate.dart';
import 'hourtv_settings_kit.dart';

class HourTvParentalSettingsPage extends StatefulWidget {
  const HourTvParentalSettingsPage({super.key});

  @override
  State<HourTvParentalSettingsPage> createState() =>
      _HourTvParentalSettingsPageState();
}

class _HourTvParentalSettingsPageState
    extends State<HourTvParentalSettingsPage> {
  late bool enabled;

  @override
  void initState() {
    super.initState();
    enabled = ParentalControlService.isEnabled;
  }

  Future<void> _setEnabled(bool value) async {
    if (value) {
      final pins = await requestNewParentalPin(
        context,
        title: 'Crear PIN parental',
      );
      if (pins == null) return;
      if (pins.$1 != pins.$2) {
        _message('Los PIN no coinciden.');
        return;
      }
      try {
        await ParentalControlService.enable(pins.$1);
      } on ArgumentError {
        _message('El PIN debe contener entre 4 y 6 dígitos.');
        return;
      }
    } else {
      final pin = await requestParentalPin(
        context,
        title: 'Desactivar modo restringido',
      );
      if (pin == null) return;
      try {
        await ParentalControlService.disable(pin);
      } on ParentalPinException {
        _message('PIN incorrecto.');
        return;
      }
    }

    ContentStore.instance.refreshParentalFilter();
    if (mounted) setState(() => enabled = value);
  }

  Future<void> _changePin() async {
    final current = await requestParentalPin(context, title: 'PIN actual');
    if (current == null || !mounted) return;
    if (!ParentalControlService.verifyPin(current)) {
      _message('PIN incorrecto.');
      return;
    }

    final next = await requestNewParentalPin(
      context,
      title: 'Nuevo PIN parental',
    );
    if (next == null) return;
    if (next.$1 != next.$2) {
      _message('Los PIN no coinciden.');
      return;
    }
    try {
      await ParentalControlService.enable(next.$1);
      _message('PIN actualizado.');
    } on ArgumentError {
      _message('El PIN debe contener entre 4 y 6 dígitos.');
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return HourTvSettingsScaffold(
      title: 'Control parental',
      children: [
        SettingsToggleRow(
          icon: Icons.family_restroom_rounded,
          title: 'Modo restringido',
          subtitle: enabled
              ? 'Contenido adulto oculto. Se requiere el PIN para desactivarlo.'
              : 'Oculta contenido clasificado como adulto o maduro.',
          value: enabled,
          autofocus: true,
          onChanged: _setEnabled,
        ),
        if (enabled)
          SettingsChoiceRow(
            icon: Icons.pin_rounded,
            title: 'Cambiar PIN',
            subtitle: 'Solicita el PIN actual antes de reemplazarlo.',
            onTap: _changePin,
          ),
      ],
    );
  }
}
