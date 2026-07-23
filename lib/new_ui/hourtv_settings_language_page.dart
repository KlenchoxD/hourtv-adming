import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import 'hourtv_settings_kit.dart';

/// Claves de preferencias reales (leidas por el reproductor):
/// - preferredAudioLanguage: 'es' | 'en' | 'auto'. Si la fuente ofrece varias
///   pistas de audio, HourTV selecciona la que coincida al empezar a
///   reproducir (usa la misma API real de pistas que ya usa el selector
///   manual de audio del reproductor).
/// - subtitleFontScale: tamaño de letra de subtitulos (0.85 / 1.0 / 1.3).
/// - subtitleBold: negrita en subtitulos.
class HourTvLanguageSettingsPage extends StatefulWidget {
  const HourTvLanguageSettingsPage({super.key});

  @override
  State<HourTvLanguageSettingsPage> createState() =>
      _HourTvLanguageSettingsPageState();
}

class _HourTvLanguageSettingsPageState
    extends State<HourTvLanguageSettingsPage> {
  late String audioLanguage;
  late double subtitleScale;
  late bool subtitleBold;

  static const _languages = <(String, String)>[
    ('auto', 'Automático (el de la fuente)'),
    ('es', 'Español'),
    ('en', 'Inglés'),
  ];

  static const _sizes = <(double, String)>[
    (0.85, 'Pequeño'),
    (1.0, 'Mediano'),
    (1.3, 'Grande'),
  ];

  @override
  void initState() {
    super.initState();
    audioLanguage =
        (StorageService.getSetting(
                  'preferredAudioLanguage',
                  defaultValue: 'auto',
                ) ??
                'auto')
            .toString();
    subtitleScale =
        double.tryParse(
          StorageService.getSetting(
            'subtitleFontScale',
            defaultValue: 1.0,
          ).toString(),
        ) ??
        1.0;
    subtitleBold =
        StorageService.getSetting('subtitleBold', defaultValue: false) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    return HourTvSettingsScaffold(
      title: 'Idioma y subtítulos',
      children: [
        const SettingsSectionLabel('Audio'),
        for (var i = 0; i < _languages.length; i++)
          SettingsRadioRow(
            title: _languages[i].$2,
            selected: audioLanguage == _languages[i].$1,
            autofocus: i == 0,
            onTap: () {
              setState(() => audioLanguage = _languages[i].$1);
              StorageService.saveSetting(
                'preferredAudioLanguage',
                _languages[i].$1,
              );
            },
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Text(
            'Si el canal o película ofrece esa pista de audio, se '
            'selecciona automáticamente al reproducir.',
            style: TextStyle(color: kSetMuted, fontSize: 12),
          ),
        ),
        const SettingsSectionLabel('Subtítulos'),
        for (var i = 0; i < _sizes.length; i++)
          SettingsRadioRow(
            title: 'Tamaño de letra: ${_sizes[i].$2}',
            selected: subtitleScale == _sizes[i].$1,
            onTap: () {
              setState(() => subtitleScale = _sizes[i].$1);
              StorageService.saveSetting('subtitleFontScale', _sizes[i].$1);
            },
          ),
        SettingsRadioRow(
          title: 'Negrita',
          checkbox: true,
          selected: subtitleBold,
          onTap: () {
            setState(() => subtitleBold = !subtitleBold);
            StorageService.saveSetting('subtitleBold', !subtitleBold);
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            'Se aplica cuando el contenido incluye subtítulos. La mayoría de '
            'canales en vivo no traen pista de subtítulos.',
            style: TextStyle(color: kSetMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
