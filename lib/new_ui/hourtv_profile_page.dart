import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storage_service.dart';
import 'hourtv_focusable.dart';
import 'hourtv_settings_language_page.dart';
import 'hourtv_settings_page.dart';
import 'hourtv_settings_parental_page.dart';
import 'hourtv_settings_playback_page.dart';

const _red = Color(0xFFF20A1A);
const _surface = Color(0xFF111113);
const _line = Color(0xFF29292E);
const _muted = Color(0xFFA6A6B0);

class HourTvProfilePage extends StatefulWidget {
  const HourTvProfilePage({
    super.key,
    required this.phone,
    required this.tablet,
    required this.tv,
  });

  final bool phone;
  final bool tablet;
  final bool tv;

  @override
  State<HourTvProfilePage> createState() => _HourTvProfilePageState();
}

class _HourTvProfilePageState extends State<HourTvProfilePage> {
  String profile = 'Invitado';

  static const profiles = <(String, IconData)>[
    ('Invitado', Icons.person_rounded),
    ('Cinéfilo', Icons.local_movies_rounded),
    ('Kids', Icons.child_care_rounded),
  ];

  /// Los subtitulos de cada tarjeta se calculan del ajuste GUARDADO, no son
  /// texto fijo: antes "Control parental" decia siempre "Desactivado" aunque
  /// estuviera activado.
  List<(IconData, String, String)> get tvOptions {
    final audio = StorageService.getSetting(
      'preferredAudioLanguage',
      defaultValue: 'auto',
    ).toString();
    final audioLabel = switch (audio) {
      'es' => 'Audio en español',
      'en' => 'Audio en inglés',
      _ => 'Audio automático',
    };
    final autoPlay =
        StorageService.getSetting('autoPlay', defaultValue: true) == true;
    final parental =
        StorageService.getSetting(
          'parentalControlEnabled',
          defaultValue: false,
        ) ==
        true;
    return [
      (
        Icons.high_quality_rounded,
        'Reproducción y calidad',
        autoPlay ? 'Calidad automática · Auto-play' : 'Calidad automática',
      ),
      (Icons.subtitles_rounded, 'Idioma y subtítulos', audioLabel),
      (Icons.settings_rounded, 'Configuración', 'Actualizaciones y más'),
      (
        Icons.family_restroom_rounded,
        'Control parental',
        parental ? 'Activado' : 'Desactivado',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    profile = (StorageService.getSetting(
      'activeProfile',
      defaultValue: 'Invitado',
    )).toString();
  }

  void _selectProfile(String value) {
    setState(() => profile = value);
    unawaited(StorageService.saveSetting('activeProfile', value));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phone) return _mobile();
    if (widget.tablet) return _tablet();
    return _desktopAndTv();
  }

  Widget _mobile() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Tu Perfil', 28),
                const SizedBox(height: 20),
                _profileCard(compact: true),
                const SizedBox(height: 24),
                const Text(
                  'CAMBIAR DE PERFIL',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var index = 0; index < profiles.length; index++) ...[
                      if (index > 0) const SizedBox(width: 10),
                      Expanded(child: _mobileProfile(profiles[index])),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                // Mismos apartados que en TV: antes el Perfil de telefono solo
                // tenia dos interruptores (uno de ellos, Notificaciones, no
                // hacia nada) y no habia forma de llegar a Configuracion,
                // Actualizaciones, Idioma ni Control parental.
                for (final option in tvOptions) ...[
                  _optionRow(option),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: TextButton(
                    onPressed: () {
                      _selectProfile('Invitado');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sesión cerrada.')),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: _red,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tablet() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Perfil', 34),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: _panelDecoration(),
                        child: Column(
                          children: [
                            _avatar(40, Icons.local_movies_rounded),
                            const SizedBox(height: 15),
                            Text(
                              '$profile (Cinéfilo)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Plan Premium · 4K HDR',
                              style: TextStyle(
                                color: _red,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton(
                              onPressed: () {
                                final current = profiles.indexWhere(
                                  (item) => item.$1 == profile,
                                );
                                _selectProfile(
                                  profiles[(current + 1) % profiles.length].$1,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: _line),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: const Text('Cambiar avatar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: _panelDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ajustes del dispositivo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Antes habia dos interruptores ("Descargas en
                            // alta calidad" y "Reproduccion automatica del
                            // siguiente episodio") que se guardaban pero
                            // ningun codigo leia: no hacian nada. Se
                            // reemplazan por los apartados reales.
                            for (final option in tvOptions) ...[
                              _optionRow(option),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopAndTv() {
    final isTv = widget.tv;
    // Se calcula una vez por build: tvOptions es un getter que lee ajustes.
    final options = tvOptions;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: EdgeInsets.all(isTv ? 48 : 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _avatar(isTv ? 48 : 42, Icons.person_rounded),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PERFIL',
                                style: TextStyle(
                                  color: _red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                profile,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: isTv ? 48 : 40,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'Suscripción Premium · Ultra HD 4K',
                                style: TextStyle(color: _muted, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTv ? 36 : 28),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: options.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 3.7,
                          ),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final card = _tvOption(option);
                        if (!isTv) return card;
                        return TvFocusable(
                          autofocus: index == 0,
                          onTap: () => _openSetting(option.$2),
                          borderRadius: BorderRadius.circular(16),
                          child: card,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tvOption((IconData, String, String) option) {
    return InkWell(
      onTap: () => _openSetting(option.$2),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: _panelDecoration(radius: 16),
        child: Row(
          children: [
            Icon(option.$1, color: _red, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(option.$3, style: const TextStyle(color: _muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  /// Fila de apartado para telefono y tablet (en TV se usa `_tvOption` dentro
  /// de la cuadricula con foco de D-pad).
  Widget _optionRow((IconData, String, String) option) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openSetting(option.$2),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Icon(option.$1, color: _red, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.$3,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  // Cada opcion abre SU PROPIA pantalla con contenido real y distinto -
  // antes todas reusaban la misma pagina generica y mostraban lo mismo.
  Future<void> _openSetting(String title) async {
    final page = switch (title) {
      'Reproducción y calidad' => const HourTvPlaybackSettingsPage(),
      'Idioma y subtítulos' => const HourTvLanguageSettingsPage(),
      'Control parental' => const HourTvParentalSettingsPage(),
      _ => const HourTvSettingsPage(),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    // Al volver, releer los ajustes para que los subtitulos de las tarjetas
    // muestren el valor nuevo (ej. Control parental: Activado).
    if (mounted) setState(() {});
  }

  Widget _profileCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          _avatar(compact ? 32 : 38, Icons.person_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Suscripción Premium · 4K HDR',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 3),
                const Text(
                  'ID: HTV-3000',
                  style: TextStyle(
                    color: _red,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileProfile((String, IconData) item) {
    final selected = item.$1 == profile;
    return InkWell(
      onTap: () => _selectProfile(item.$1),
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? _red : _line, width: 2),
        ),
        child: Column(
          children: [
            Icon(item.$2, color: selected ? Colors.white : _muted, size: 27),
            const SizedBox(height: 6),
            Text(
              item.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(double radius, IconData icon) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _red,
      child: Icon(icon, color: Colors.white, size: radius),
    );
  }

  Widget _title(String value, double size) => Text(
    value,
    style: GoogleFonts.inter(
      color: Colors.white,
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: -.7,
    ),
  );

  BoxDecoration _panelDecoration({double radius = 18}) => BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _line),
  );
}
