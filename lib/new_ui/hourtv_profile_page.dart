import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storage_service.dart';
import 'hourtv_focusable.dart';
import 'hourtv_settings_page.dart';

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
  bool wifiDownloads = true;
  bool smartNotifications = false;
  bool highQualityDownloads = true;
  bool autoplayNext = true;

  static const profiles = <(String, IconData)>[
    ('Invitado', Icons.person_rounded),
    ('Cinéfilo', Icons.local_movies_rounded),
    ('Kids', Icons.child_care_rounded),
  ];

  static const tvOptions = <(IconData, String, String)>[
    (Icons.high_quality_rounded, 'Reproducción y calidad', 'Ultra HD 4K'),
    (Icons.subtitles_rounded, 'Idioma y subtítulos', 'Español'),
    (Icons.notifications_active_rounded, 'Notificaciones', 'Activadas'),
    (Icons.family_restroom_rounded, 'Control parental', 'Desactivado'),
  ];

  @override
  void initState() {
    super.initState();
    profile = (StorageService.getSetting(
      'activeProfile',
      defaultValue: 'Invitado',
    )).toString();
    wifiDownloads =
        StorageService.getSetting('wifiOnly', defaultValue: true) == true;
    smartNotifications =
        StorageService.getSetting('smartNotifications', defaultValue: false) ==
        true;
    highQualityDownloads =
        StorageService.getSetting('highQualityDownloads', defaultValue: true) ==
        true;
    autoplayNext =
        StorageService.getSetting('autoPlayNextEpisode', defaultValue: true) ==
        true;
  }

  void _selectProfile(String value) {
    setState(() => profile = value);
    unawaited(StorageService.saveSetting('activeProfile', value));
  }

  void _saveBool(String key, bool value, VoidCallback update) {
    setState(update);
    unawaited(StorageService.saveSetting(key, value));
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
                Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    children: [
                      _switchRow(
                        title: 'Descargas solo por Wi-Fi',
                        value: wifiDownloads,
                        onChanged: (value) => _saveBool(
                          'wifiOnly',
                          value,
                          () => wifiDownloads = value,
                        ),
                      ),
                      const Divider(height: 1, color: _line),
                      _switchRow(
                        title: 'Notificaciones inteligentes',
                        value: smartNotifications,
                        onChanged: (value) => _saveBool(
                          'smartNotifications',
                          value,
                          () => smartNotifications = value,
                        ),
                      ),
                      const Divider(height: 1, color: _line),
                      TextButton(
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
                    ],
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
                            const SizedBox(height: 10),
                            const Divider(color: _line),
                            _switchRow(
                              title: 'Descargas en alta calidad',
                              subtitle:
                                  'Utilizar almacenamiento interno para descargas en 1080p',
                              value: highQualityDownloads,
                              onChanged: (value) => _saveBool(
                                'highQualityDownloads',
                                value,
                                () => highQualityDownloads = value,
                              ),
                            ),
                            const Divider(height: 1, color: _line),
                            _switchRow(
                              title:
                                  'Reproducción automática del siguiente episodio',
                              subtitle:
                                  'Iniciar automáticamente el próximo episodio de una serie',
                              value: autoplayNext,
                              onChanged: (value) => _saveBool(
                                'autoPlayNextEpisode',
                                value,
                                () => autoplayNext = value,
                              ),
                            ),
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
                      itemCount: tvOptions.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 3.7,
                          ),
                      itemBuilder: (context, index) {
                        final option = tvOptions[index];
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

  void _openSetting(String title) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => HourTvSettingsPage(title: title)));
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

  Widget _switchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _red,
          ),
        ],
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
