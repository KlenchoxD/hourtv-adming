import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/iptv_server_service.dart';
import '../services/storage_service.dart';
import 'hourtv_settings_kit.dart';
import 'hourtv_settings_update_page.dart';

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

  Future<void> _pickSort() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kSetSurface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Orden del catálogo',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            ListTile(
              leading: Icon(
                sortBy == 'name'
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: sortBy == 'name' ? kSetRed : kSetMuted,
              ),
              title: const Text(
                'Nombre',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(sheetContext, 'name'),
            ),
            ListTile(
              leading: Icon(
                sortBy == 'group'
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: sortBy == 'group' ? kSetRed : kSetMuted,
              ),
              title: const Text(
                'Categoría / grupo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(sheetContext, 'group'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => sortBy = selected);
    await StorageService.saveSetting('sortBy', selected);
  }

  @override
  Widget build(BuildContext context) {
    return HourTvSettingsScaffold(
      title: widget.title,
      children: [
        const SettingsSectionLabel('Actualizaciones'),
        SettingsChoiceRow(
          icon: Icons.system_update_rounded,
          title: 'Buscar actualizaciones',
          subtitle: 'Descarga e instala nuevas versiones desde GitHub',
          autofocus: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HourTvUpdatePage()),
          ),
        ),
        const SettingsSectionLabel('Catálogo y datos'),
        SettingsToggleRow(
          icon: Icons.wifi_rounded,
          title: 'Solo por Wi‑Fi',
          subtitle: 'Evitar cargas usando datos móviles',
          value: wifiOnly,
          onChanged: (value) {
            setState(() => wifiOnly = value);
            StorageService.saveSetting('wifiOnly', value);
          },
        ),
        SettingsChoiceRow(
          icon: Icons.sort_rounded,
          title: 'Orden del catálogo',
          subtitle: sortBy == 'group' ? 'Categoría / grupo' : 'Nombre',
          onTap: _pickSort,
        ),
        const SettingsSectionLabel('Servidor IPTV local'),
        SettingsToggleRow(
          icon: Icons.router_rounded,
          title: 'Compartir catálogo por red',
          subtitle: serverEnabled
              ? (serverUrl ?? 'Iniciando servidor…')
              : 'Desactivado',
          value: serverEnabled,
          onChanged: _toggleServer,
        ),
        if (serverEnabled && serverUrl != null)
          SettingsChoiceRow(
            icon: Icons.copy_rounded,
            title: 'Copiar URL del servidor',
            subtitle: serverUrl!,
            onTap: () {
              Clipboard.setData(ClipboardData(text: serverUrl!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copiada al portapapeles.')),
              );
            },
          ),
        const SettingsSectionLabel('HourTV'),
        const SettingsInfoRow(
          icon: Icons.info_outline_rounded,
          title: 'Acerca de',
          subtitle: 'Diseño adaptable para móvil, tablet, desktop y TV',
        ),
      ],
    );
  }
}
