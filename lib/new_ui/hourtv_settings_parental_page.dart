import 'package:flutter/material.dart';

import '../services/storage_service.dart';
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
    enabled =
        StorageService.getSetting(
          'parentalControlEnabled',
          defaultValue: false,
        ) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    return HourTvSettingsScaffold(
      title: 'Control parental',
      children: [
        SettingsToggleRow(
          icon: Icons.family_restroom_rounded,
          title: 'Activar control parental',
          subtitle:
              'Restringe contenido para adultos cuando esté disponible en '
              'el catálogo.',
          value: enabled,
          autofocus: true,
          onChanged: (value) {
            setState(() => enabled = value);
            StorageService.saveSetting('parentalControlEnabled', value);
          },
        ),
      ],
    );
  }
}
