import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/iptv_server_service.dart';
import '../services/storage_service.dart';
import 'hourtv_settings_update_page.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

class HourTvSettingsPage extends StatefulWidget {
  const HourTvSettingsPage({super.key, this.title = 'Configuración'});
  final String title;

  @override
  State<HourTvSettingsPage> createState() => _HourTvSettingsPageState();
}

class _HourTvSettingsPageState extends State<HourTvSettingsPage> {
  late bool wifiOnly;
  late bool serverEnabled;
  late String sortBy;
  String? serverUrl;

  @override
  void initState() {
    super.initState();
    wifiOnly =
        StorageService.getSetting('wifiOnly', defaultValue: false) == true;
    sortBy =
        (StorageService.getSetting('sortBy', defaultValue: 'name') ?? 'name')
            .toString();
    serverEnabled =
        StorageService.getSetting('iptv_server_enabled', defaultValue: false) ==
        true;
    serverUrl = IptvServerService.instance.localUrl.value;
    IptvServerService.instance.isRunning.addListener(_serverChanged);
    IptvServerService.instance.localUrl.addListener(_serverChanged);
  }

  @override
  void dispose() {
    IptvServerService.instance.isRunning.removeListener(_serverChanged);
    IptvServerService.instance.localUrl.removeListener(_serverChanged);
    super.dispose();
  }

  void _serverChanged() {
    if (!mounted) return;
    setState(() {
      serverEnabled = IptvServerService.instance.isRunning.value;
      serverUrl = IptvServerService.instance.localUrl.value;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    await StorageService.saveSetting(key, value);
  }

  Future<void> _toggleServer(bool enabled) async {
    setState(() => serverEnabled = enabled);
    await StorageService.saveSetting('iptv_server_enabled', enabled);
    try {
      if (enabled) {
        await IptvServerService.instance.start();
      } else {
        await IptvServerService.instance.stop();
      }
    } catch (_) {
      await StorageService.saveSetting('iptv_server_enabled', false);
      if (!mounted) return;
      setState(() {
        serverEnabled = false;
        serverUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar el servidor IPTV.')),
      );
    }
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
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _sectionTitle('Actualizaciones'),
              _ChoiceTile(
                icon: Icons.system_update_rounded,
                title: 'Buscar actualizaciones',
                subtitle: 'Descarga e instala nuevas versiones desde GitHub',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HourTvUpdatePage(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Catálogo y datos'),
              _ToggleTile(
                icon: Icons.wifi_rounded,
                title: 'Solo por Wi‑Fi',
                subtitle: 'Evitar cargas usando datos móviles',
                value: wifiOnly,
                onChanged: (value) {
                  setState(() => wifiOnly = value);
                  _saveBool('wifiOnly', value);
                },
              ),
              _ChoiceTile(
                icon: Icons.sort_rounded,
                title: 'Orden del catálogo',
                subtitle: sortBy == 'group' ? 'Categoría / grupo' : 'Nombre',
                onTap: _pickSort,
              ),
              const SizedBox(height: 24),
              _sectionTitle('Servidor IPTV local'),
              _ToggleTile(
                icon: Icons.router_rounded,
                title: 'Compartir catálogo por red',
                subtitle: serverEnabled
                    ? (serverUrl ?? 'Iniciando servidor…')
                    : 'Desactivado',
                value: serverEnabled,
                onChanged: _toggleServer,
              ),
              if (serverEnabled && serverUrl != null)
                _ChoiceTile(
                  icon: Icons.copy_rounded,
                  title: 'Copiar URL del servidor',
                  subtitle: serverUrl!,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: serverUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URL copiada al portapapeles.'),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              _sectionTitle('HourTV'),
              const _InfoTile(
                icon: Icons.info_outline_rounded,
                title: 'Acerca de',
                subtitle: 'Diseño adaptable para móvil, tablet, desktop y TV',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
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

  Future<void> _pickSort() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Orden del catálogo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            ListTile(
              leading: Icon(
                sortBy == 'name'
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: sortBy == 'name' ? _red : _muted,
              ),
              title: const Text('Nombre'),
              onTap: () => Navigator.pop(sheetContext, 'name'),
            ),
            ListTile(
              leading: Icon(
                sortBy == 'group'
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: sortBy == 'group' ? _red : _muted,
              ),
              title: const Text('Categoría / grupo'),
              onTap: () => Navigator.pop(sheetContext, 'group'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => sortBy = selected);
    await StorageService.saveSetting('sortBy', selected);
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

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _BaseTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
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
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
