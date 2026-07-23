import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import 'hourtv_settings_kit.dart';

class HourTvPlaybackSettingsPage extends StatefulWidget {
  const HourTvPlaybackSettingsPage({super.key});

  @override
  State<HourTvPlaybackSettingsPage> createState() =>
      _HourTvPlaybackSettingsPageState();
}

class _HourTvPlaybackSettingsPageState
    extends State<HourTvPlaybackSettingsPage> {
  late bool autoPlay;
  late bool forceLandscape;

  @override
  void initState() {
    super.initState();
    autoPlay =
        StorageService.getSetting('autoPlay', defaultValue: true) == true;
    forceLandscape =
        StorageService.getSetting('forceLandscape', defaultValue: false) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    return HourTvSettingsScaffold(
      title: 'Reproducción y calidad',
      children: [
        SettingsToggleRow(
          icon: Icons.play_circle_outline_rounded,
          title: 'Reproducción automática',
          subtitle: 'Iniciar de inmediato al abrir un canal o título',
          value: autoPlay,
          autofocus: true,
          onChanged: (value) {
            setState(() => autoPlay = value);
            StorageService.saveSetting('autoPlay', value);
          },
        ),
        SettingsToggleRow(
          icon: Icons.screen_rotation_rounded,
          title: 'Forzar horizontal',
          subtitle: 'Rotar la pantalla al entrar al reproductor',
          value: forceLandscape,
          onChanged: (value) {
            setState(() => forceLandscape = value);
            StorageService.saveSetting('forceLandscape', value);
          },
        ),
        const SettingsSectionLabel('Servidor y calidad'),
        const SettingsInfoRow(
          icon: Icons.dns_rounded,
          title: 'Servidor',
          subtitle:
              'Cuando un canal ofrece varios servidores, cámbialo desde el '
              'reproductor (ícono de ajustes, arriba a la derecha).',
        ),
        const SettingsInfoRow(
          icon: Icons.high_quality_rounded,
          title: 'Calidad',
          subtitle:
              'Automática: HourTV ajusta la resolución según tu conexión y '
              'lo que ofrezca la fuente. No hay selector manual porque la '
              'mayoría de fuentes IPTV solo entregan una calidad.',
        ),
      ],
    );
  }
}
