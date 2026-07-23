import 'package:flutter/material.dart';

import '../services/storage_service.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

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
          'Reproducción y calidad',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _ToggleTile(
                icon: Icons.play_circle_outline_rounded,
                title: 'Reproducción automática',
                subtitle: 'Iniciar de inmediato al abrir un canal o título',
                value: autoPlay,
                onChanged: (value) {
                  setState(() => autoPlay = value);
                  StorageService.saveSetting('autoPlay', value);
                },
              ),
              _ToggleTile(
                icon: Icons.screen_rotation_rounded,
                title: 'Forzar horizontal',
                subtitle: 'Rotar la pantalla al entrar al reproductor',
                value: forceLandscape,
                onChanged: (value) {
                  setState(() => forceLandscape = value);
                  StorageService.saveSetting('forceLandscape', value);
                },
              ),
              const SizedBox(height: 24),
              const _InfoTile(
                icon: Icons.dns_rounded,
                title: 'Servidor',
                subtitle:
                    'Cuando un canal ofrece varios servidores, cámbialo desde '
                    'el reproductor (ícono de ajustes, arriba a la derecha).',
              ),
              const _InfoTile(
                icon: Icons.high_quality_rounded,
                title: 'Calidad',
                subtitle:
                    'Automática: HourTV ajusta la resolución según tu conexión '
                    'y lo que ofrezca la fuente. No hay selector manual porque '
                    'la mayoría de fuentes IPTV solo entregan una calidad.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _BaseTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    trailing: Switch(
      value: value,
      activeThumbColor: _red,
      onChanged: onChanged,
    ),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) =>
      _BaseTile(icon: icon, title: title, subtitle: subtitle);
}

class _BaseTile extends StatelessWidget {
  const _BaseTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
