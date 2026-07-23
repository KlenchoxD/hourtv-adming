import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/update_service.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

enum _Stage { idle, checking, upToDate, available, downloading, ready, error }

class HourTvUpdatePage extends StatefulWidget {
  const HourTvUpdatePage({super.key});

  @override
  State<HourTvUpdatePage> createState() => _HourTvUpdatePageState();
}

class _HourTvUpdatePageState extends State<HourTvUpdatePage> {
  _Stage _stage = _Stage.idle;
  String? _currentVersion;
  UpdateInfo? _info;
  String? _error;
  double _progress = 0;
  String? _downloadedPath;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _currentVersion = info.version);
    });
  }

  Future<void> _check() async {
    setState(() {
      _stage = _Stage.checking;
      _error = null;
    });
    final result = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    switch (result) {
      case UpToDate():
        setState(() => _stage = _Stage.upToDate);
      case UpdateAvailable(:final info):
        setState(() {
          _info = info;
          _stage = _Stage.available;
        });
      case UpdateCheckFailed(:final reason):
        setState(() {
          _error = reason;
          _stage = _Stage.error;
        });
    }
  }

  Future<void> _download() async {
    final info = _info;
    if (info == null) return;
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
    });
    try {
      final path = await UpdateService.instance.preparedDownloadPath(
        info.version,
      );
      await for (final progress in UpdateService.instance.download(
        info,
        path,
      )) {
        if (!mounted) return;
        setState(() => _progress = progress);
      }
      if (!mounted) return;
      setState(() {
        _downloadedPath = path;
        _stage = _Stage.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'La descarga falló: $error';
        _stage = _Stage.error;
      });
    }
  }

  Future<void> _install() async {
    final path = _downloadedPath;
    if (path == null) return;
    final result = await UpdateService.instance.install(path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      setState(() {
        _error = result.message.isNotEmpty
            ? result.message
            : 'No se pudo abrir el instalador.';
        _stage = _Stage.error;
      });
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
        title: const Text(
          'Actualizaciones',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smartphone_rounded, color: _red),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Versión instalada',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _currentVersion ?? '…',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_stage) {
      case _Stage.idle:
        return _actionButton(
          label: 'Buscar actualizaciones',
          icon: Icons.refresh_rounded,
          onTap: _check,
        );
      case _Stage.checking:
        return const _StatusCard(
          icon: null,
          loading: true,
          title: 'Buscando…',
          subtitle: 'Consultando la última versión publicada en GitHub.',
        );
      case _Stage.upToDate:
        return Column(
          children: [
            const _StatusCard(
              icon: Icons.check_circle_rounded,
              iconColor: Color(0xFF00D6A0),
              title: 'Ya tienes la última versión',
              subtitle: 'No hay actualizaciones disponibles por ahora.',
            ),
            const SizedBox(height: 16),
            _actionButton(
              label: 'Volver a buscar',
              icon: Icons.refresh_rounded,
              onTap: _check,
            ),
          ],
        );
      case _Stage.available:
        final info = _info!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(
              icon: Icons.system_update_rounded,
              iconColor: _red,
              title: 'Versión ${info.version} disponible',
              subtitle: info.notes.isEmpty
                  ? 'Nueva versión lista para descargar.'
                  : info.notes,
            ),
            const SizedBox(height: 16),
            _actionButton(
              label: 'Descargar e instalar',
              icon: Icons.download_rounded,
              onTap: _download,
            ),
          ],
        );
      case _Stage.downloading:
        return Column(
          children: [
            _StatusCard(
              icon: null,
              loading: true,
              title: 'Descargando…',
              subtitle: '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 8,
                color: _red,
                backgroundColor: _surface,
              ),
            ),
          ],
        );
      case _Stage.ready:
        return Column(
          children: [
            const _StatusCard(
              icon: Icons.check_circle_rounded,
              iconColor: Color(0xFF00D6A0),
              title: 'Descarga lista',
              subtitle:
                  'Toca instalar y confirma en el instalador de Android.',
            ),
            const SizedBox(height: 16),
            _actionButton(
              label: 'Instalar ahora',
              icon: Icons.install_mobile_rounded,
              onTap: _install,
            ),
          ],
        );
      case _Stage.error:
        return Column(
          children: [
            _StatusCard(
              icon: Icons.error_outline_rounded,
              iconColor: const Color(0xFFFF5A66),
              title: 'No se pudo completar',
              subtitle: _error ?? 'Ocurrió un error inesperado.',
            ),
            const SizedBox(height: 16),
            _actionButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              onTap: _check,
            ),
          ],
        );
    }
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _red,
        minimumSize: const Size.fromHeight(52),
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = _muted,
    this.loading = false,
  });

  final IconData? icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: _red),
            )
          else
            Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
