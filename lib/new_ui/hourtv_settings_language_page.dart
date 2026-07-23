import 'package:flutter/material.dart';

import '../services/storage_service.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

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
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Idioma y subtítulos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _sectionTitle('Audio'),
              for (final option in _languages)
                _ChoiceRow(
                  title: option.$2,
                  selected: audioLanguage == option.$1,
                  onTap: () {
                    setState(() => audioLanguage = option.$1);
                    StorageService.saveSetting(
                      'preferredAudioLanguage',
                      option.$1,
                    );
                  },
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 20),
                child: Text(
                  'Si el canal o película ofrece esa pista de audio, se '
                  'selecciona automáticamente al reproducir.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
              _sectionTitle('Subtítulos'),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  'Tamaño y estilo de letra',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final size in _sizes) ...[
                    Expanded(
                      child: _SizeChip(
                        label: size.$2,
                        selected: subtitleScale == size.$1,
                        scale: size.$1,
                        onTap: () {
                          setState(() => subtitleScale = size.$1);
                          StorageService.saveSetting(
                            'subtitleFontScale',
                            size.$1,
                          );
                        },
                      ),
                    ),
                    if (size != _sizes.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _ChoiceRow(
                title: 'Negrita',
                selected: subtitleBold,
                onTap: () {
                  setState(() => subtitleBold = !subtitleBold);
                  StorageService.saveSetting('subtitleBold', !subtitleBold);
                },
                trailingCheckbox: true,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  'Se aplica cuando el contenido incluye subtítulos. La '
                  'mayoría de canales en vivo no traen pista de subtítulos.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 9),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailingCheckbox = false,
  });
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final bool trailingCheckbox;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? _red : _line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  trailingCheckbox
                      ? (selected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded)
                      : (selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded),
                  color: selected ? _red : _muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.scale,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: selected ? _red : _line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  color: selected ? Colors.white : _muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 17 * scale,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
