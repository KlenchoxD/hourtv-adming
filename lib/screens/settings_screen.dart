import 'package:flutter/material.dart';
import '../services/content_store.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _sortBy = 'name';
  bool _autoPlay = true;
  bool _forceLandscape = false;
  bool _wifiOnly = false;
  bool _tmdbConfigured = false;
  bool _remoteConfigured = false;

  @override
  void initState() {
    super.initState();
    _sortBy =
        StorageService.getSetting('sortBy', defaultValue: 'name') as String;
    _autoPlay =
        StorageService.getSetting('autoPlay', defaultValue: true) == true;
    _forceLandscape =
        StorageService.getSetting('forceLandscape', defaultValue: false) ==
        true;
    _wifiOnly =
        StorageService.getSetting('wifiOnly', defaultValue: false) == true;
    _tmdbConfigured =
        (StorageService.getSetting('tmdbApiKey', defaultValue: '') ?? '')
            .toString()
            .trim()
            .isNotEmpty;
    _remoteConfigured =
        (StorageService.getSetting('remoteSourcesUrl', defaultValue: '') ?? '')
            .toString()
            .trim()
            .isNotEmpty;
  }

  Future<void> _set(String key, dynamic value) async {
    await StorageService.saveSetting(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        itemCount: 7,
        itemBuilder: (context, index) {
          return switch (index) {
            0 => RepaintBoundary(child: _header()),
            1 => _section('Canales', [
              _choice(
                icon: Icons.sort,
                title: 'Ordenar por',
                subtitle: _sortBy == 'group' ? 'Categoría / grupo' : 'Nombre',
                onTap: _showSortDialog,
              ),
            ]),
            2 => _section('Reproducción', [
              _toggle(
                icon: Icons.play_circle_outline,
                title: 'Auto-play',
                subtitle: 'Iniciar reproducción al abrir un canal',
                value: _autoPlay,
                onChanged: (value) async {
                  setState(() => _autoPlay = value);
                  await _set('autoPlay', value);
                },
              ),
              _toggle(
                icon: Icons.screen_rotation,
                title: 'Forzar horizontal',
                subtitle: 'Rotar pantalla al entrar al reproductor',
                value: _forceLandscape,
                onChanged: (value) async {
                  setState(() => _forceLandscape = value);
                  await _set('forceLandscape', value);
                },
              ),
            ]),
            3 => _section('Red y datos', [
              _toggle(
                icon: Icons.wifi,
                title: 'Solo por WiFi',
                subtitle: 'No cargar canales usando datos móviles',
                value: _wifiOnly,
                onChanged: (value) async {
                  setState(() => _wifiOnly = value);
                  await _set('wifiOnly', value);
                },
              ),
              _choice(
                icon: Icons.delete_sweep_outlined,
                title: 'Limpiar caché',
                subtitle: 'Elimina logos descargados e historial reciente',
                onTap: _clearCache,
              ),
            ]),
            4 => _section('Metadata', [
              _choice(
                icon: Icons.movie_filter_outlined,
                title: 'API Key de TMDB',
                subtitle: _tmdbConfigured
                    ? 'Configurada — sinopsis y reparto activos'
                    : 'Sin configurar — sinopsis y reparto automáticos',
                onTap: _editTmdbKey,
              ),
              _choice(
                icon: Icons.cloud_sync_outlined,
                title: 'URL del catálogo remoto',
                subtitle: _remoteConfigured
                    ? 'Configurada — el catálogo se actualiza desde tu servidor'
                    : 'Sin configurar — usa el catálogo del APK',
                onTap: _editRemoteSourcesUrl,
              ),
            ]),
            5 => _section('Información', [
              _choice(
                icon: Icons.info_outline,
                title: 'Acerca de',
                subtitle: 'HourTV v1.0.0 — IPTV personal',
                onTap: _showAbout,
              ),
            ]),
            _ => const SizedBox(height: 40),
          };
        },
      ),
    );
  }

  Widget _header() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 20, 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 2),
            const Text(
              'Ajustes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      // Tarjeta de marca
      Container(
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'HourTV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Versión 1.0.0 · IPTV personal',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _section(String title, List<Widget> tiles) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(children: _withDividers(tiles)),
      ),
    ],
  );

  List<Widget> _withDividers(List<Widget> tiles) {
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 62,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        );
      }
    }
    return out;
  }

  Widget _iconChip(IconData icon) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: AppColors.accent, size: 20),
  );

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: _iconChip(icon),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.accent,
        activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
      ),
      onTap: () => onChanged(!value),
    );
  }

  Widget _choice({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: _iconChip(icon),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
        size: 22,
      ),
      onTap: onTap,
    );
  }

  Future<void> _showSortDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Ordenar canales por',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: [
          _dialogOption(ctx, 'name', 'Nombre (A-Z)'),
          _dialogOption(ctx, 'group', 'Categoría / grupo'),
        ],
      ),
    );
    if (choice != null) {
      setState(() => _sortBy = choice);
      await _set('sortBy', choice);
    }
  }

  Widget _dialogOption(BuildContext ctx, String value, String label) {
    final selected = _sortBy == value;
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, value),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Limpiar caché',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Se eliminarán las imágenes descargadas y el historial de canales recientes.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await StorageService.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caché limpiada correctamente')),
    );
  }

  Future<void> _editTmdbKey() async {
    final controller = TextEditingController(
      text: (StorageService.getSetting('tmdbApiKey', defaultValue: '') ?? '')
          .toString(),
    );
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'API Key de TMDB',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Con una key gratuita de themoviedb.org la app completa sinopsis, reparto, director y calificación de las películas automáticamente.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Pega aquí tu API key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    await _set('tmdbApiKey', saved);
    if (mounted) setState(() => _tmdbConfigured = saved.trim().isNotEmpty);
  }

  Future<void> _editRemoteSourcesUrl() async {
    final controller = TextEditingController(
      text:
          (StorageService.getSetting('remoteSourcesUrl', defaultValue: '') ??
                  '')
              .toString(),
    );
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'URL del catálogo remoto',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pega la URL pública de sources.json. Déjala vacía para usar el catálogo incluido en el APK.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'https://servidor/sources.json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    await _set('remoteSourcesUrl', saved);
    if (mounted) setState(() => _remoteConfigured = saved.trim().isNotEmpty);
    await ContentStore.instance.reload();
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'HourTV',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.live_tv,
        color: AppColors.accent,
        size: 40,
      ),
      children: const [
        Text(
          'App IPTV personal para Android, Android TV, Google TV y PC.\n\nSoporta listas M3U estándar.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
