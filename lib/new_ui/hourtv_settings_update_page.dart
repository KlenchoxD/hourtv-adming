import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/update_service.dart';
import 'hourtv_settings_kit.dart';

enum _Stage { idle, checking, upToDate, available, downloading, ready, error }

class HourTvUpdatePage extends StatefulWidget {
  const HourTvUpdatePage({super.key, this.preloadedInfo});

  /// Cuando la app ya detecto una actualizacion sola al abrirse y el
  /// usuario toco "Actualizar" en ese aviso, se llega aca con el resultado
  /// ya en mano: evita mostrar "Buscando…" y obligar a tocar de nuevo
  /// "Buscar actualizaciones" para lo mismo que ya se encontro.
  final UpdateInfo? preloadedInfo;

  @override
  State<HourTvUpdatePage> createState() => _HourTvUpdatePageState();
}

class _HourTvUpdatePageState extends State<HourTvUpdatePage> {
  late var _stage = widget.preloadedInfo != null
      ? _Stage.available
      : _Stage.idle;
  String? _currentVersion;
  late var _info = widget.preloadedInfo;
  String? _error;
  double _progress = 0;
  String? _downloadedPath;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _currentVersion = info.version);
    });
    // Ya vio el aviso: el punto verde en "Perfil" de la barra inferior no
    // tiene que seguir insistiendo, la decision de actualizar ahora es suya
    // desde esta pantalla.
    UpdateService.instance.hasUpdateAvailable.value = false;
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
    return HourTvSettingsScaffold(
      title: 'Actualizaciones',
      children: [
        SettingsInfoRow(
          icon: Icons.smartphone_rounded,
          title: 'Versión instalada',
          subtitle: _currentVersion ?? '…',
        ),
        const SizedBox(height: 6),
        ..._body(),
      ],
    );
  }

  List<Widget> _body() {
    switch (_stage) {
      case _Stage.idle:
        return [
          SettingsActionButton(
            icon: Icons.refresh_rounded,
            label: 'Buscar actualizaciones',
            autofocus: true,
            onTap: _check,
          ),
        ];
      case _Stage.checking:
        return const [
          SettingsInfoRow(
            icon: null,
            loading: true,
            title: 'Buscando…',
            subtitle: 'Consultando la última versión publicada en GitHub.',
          ),
        ];
      case _Stage.upToDate:
        return [
          const SettingsInfoRow(
            icon: Icons.check_circle_rounded,
            iconColor: Color(0xFF00C781),
            title: 'Ya tienes la última versión',
            subtitle: 'No hay actualizaciones disponibles por ahora.',
          ),
          const SizedBox(height: 6),
          SettingsActionButton(
            icon: Icons.refresh_rounded,
            label: 'Volver a buscar',
            autofocus: true,
            onTap: _check,
          ),
        ];
      case _Stage.available:
        final info = _info!;
        return [
          SettingsInfoRow(
            icon: Icons.system_update_rounded,
            iconColor: kSetRed,
            title: 'Versión ${info.version} disponible',
            subtitle: info.notes.isEmpty
                ? 'Nueva versión lista para descargar.'
                : info.notes,
          ),
          const SizedBox(height: 6),
          SettingsActionButton(
            icon: Icons.download_rounded,
            label: 'Descargar e instalar',
            autofocus: true,
            onTap: _download,
          ),
        ];
      case _Stage.downloading:
        return [
          SettingsInfoRow(
            icon: null,
            loading: true,
            title: 'Descargando…',
            subtitle:
                '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 8,
              color: kSetRed,
              backgroundColor: kSetSurface,
            ),
          ),
        ];
      case _Stage.ready:
        return [
          const SettingsInfoRow(
            icon: Icons.check_circle_rounded,
            iconColor: Color(0xFF00C781),
            title: 'Descarga lista',
            subtitle:
                'Toca instalar y confirma en el instalador de Android.',
          ),
          const SizedBox(height: 6),
          SettingsActionButton(
            icon: Icons.install_mobile_rounded,
            label: 'Instalar ahora',
            autofocus: true,
            onTap: _install,
          ),
        ];
      case _Stage.error:
        return [
          SettingsInfoRow(
            icon: Icons.error_outline_rounded,
            iconColor: const Color(0xFFFF5A66),
            title: 'No se pudo completar',
            subtitle: _error ?? 'Ocurrió un error inesperado.',
          ),
          const SizedBox(height: 6),
          SettingsActionButton(
            icon: Icons.refresh_rounded,
            label: 'Reintentar',
            autofocus: true,
            onTap: _check,
          ),
        ];
    }
  }
}
