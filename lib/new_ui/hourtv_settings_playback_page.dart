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
  late String subtitleMode;

  // Mismos valores que guarda el menú de subtítulos del reproductor
  // ('manual' = eligió un idioma ahí; se trata como "siempre").
  static const _subtitleModes = <(String, String, String)>[
    (
      'auto',
      'Automático',
      'Solo cuando el audio no está en español',
    ),
    ('always', 'Siempre en español', 'Si la película o episodio los tiene'),
    ('off', 'Desactivados', 'Puedes activarlos en el reproductor'),
  ];

  @override
  void initState() {
    super.initState();
    autoPlay =
        StorageService.getSetting('autoPlay', defaultValue: true) == true;
    forceLandscape =
        StorageService.getSetting('forceLandscape', defaultValue: false) ==
        true;
    final mode = StorageService.getSetting(
      'preferredSubtitleMode',
      defaultValue: 'auto',
    ).toString();
    subtitleMode = mode == 'manual' ? 'always' : mode;
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
        const SettingsSectionLabel('Mostrar subtítulos'),
        for (final (value, title, subtitle) in _subtitleModes)
          SettingsRadioRow(
            title: title,
            subtitle: subtitle,
            selected: subtitleMode == value,
            onTap: () {
              setState(() => subtitleMode = value);
              StorageService.saveSetting('preferredSubtitleMode', value);
              if (value == 'always') {
                StorageService.saveSetting('preferredSubtitleLanguage', 'es');
              }
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
              'Automática: se ajusta a tu conexión. Si la fuente ofrece '
              'varias calidades, elige una desde el reproductor (ajustes → '
              'Calidad).',
        ),
      ],
    );
  }
}
