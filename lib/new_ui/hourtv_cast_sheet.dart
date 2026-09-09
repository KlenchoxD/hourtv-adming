import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/channel.dart';
import '../services/cast_service.dart';

const _red = Color(0xFF00C781);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101412);
const _line = Color(0xFF27302C);
const _muted = Color(0xFFA6A6B0);

/// Panel de transmisión propio de HourTV.
///
/// Ofrece dos rutas de salida según la compatibilidad técnica del stream:
/// 1. Chromecast directo para streams compatibles con el receptor por defecto.
/// 2. Duplicación de pantalla en Android mediante ajustes del sistema (`openCastSettings`)
///    para streams con cabeceras, WebViews, o cuando no se encuentran dispositivos.
///
/// Devuelve `true` si quedó una sesión Chromecast conectada (para pausar el
/// reproductor local y abrir controles remotos). La duplicación de pantalla
/// devuelve `false` para no interrumpir la reproducción local en curso.
Future<bool> showCastSheet(
  BuildContext context, {
  required String title,
  required String Function() streamUrl,
  String? posterUrl,
  Duration Function()? position,
  Duration? Function()? duration,

  /// Tipo de contenido conocido por la app (En Vivo/película/serie).
  MediaType? mediaType,

  /// Información estructurada sobre incompatibilidad técnica con Chromecast directo.
  StreamBlockInfo? blockInfo,

  /// Motivo de bloqueo en texto plano (retrocompatibilidad).
  String? blockedReason,
}) async {
  final resolvedBlock = blockInfo ??
      (blockedReason != null
          ? StreamBlockInfo(
              reason: StreamBlockReason.requiresHeaders,
              explanation: blockedReason,
              isHeaderOrWebView: blockedReason.toLowerCase().contains('cabecera') ||
                  blockedReason.toLowerCase().contains('visor') ||
                  blockedReason.toLowerCase().contains('user-agent'),
            )
          : null);

  final connected = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CastSheet(
      title: title,
      streamUrl: streamUrl,
      posterUrl: posterUrl,
      position: position,
      duration: duration,
      mediaType: mediaType,
      blockInfo: resolvedBlock,
    ),
  );
  return connected ?? false;
}

class _CastSheet extends StatefulWidget {
  const _CastSheet({
    required this.title,
    required this.streamUrl,
    this.posterUrl,
    this.position,
    this.duration,
    this.mediaType,
    this.blockInfo,
  });

  final String title;
  final String Function() streamUrl;
  final String? posterUrl;
  final Duration Function()? position;
  final Duration? Function()? duration;
  final MediaType? mediaType;
  final StreamBlockInfo? blockInfo;

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

enum _Phase { unavailable, blocked, searching, ready, connecting, connected }

class _CastSheetState extends State<_CastSheet> {
  StreamSubscription<List<GoogleCastDevice>>? _devicesSub;
  StreamSubscription<GoogleCastSession?>? _sessionSub;
  List<GoogleCastDevice> _devices = const [];
  String? _error;
  bool _sdkAvailable = false;
  bool _connecting = false;
  String? _connectingTo;
  GoogleCastDevice? _connectedDevice;

  StreamBlockInfo? get _block => widget.blockInfo;
  bool get _isBlocked => _block != null;

  _Phase get _phase {
    if (!_sdkAvailable) return _Phase.unavailable;
    if (_connectedDevice != null) return _Phase.connected;
    if (_connecting) return _Phase.connecting;
    if (_isBlocked) return _Phase.blocked;
    if (_devices.isEmpty) return _Phase.searching;
    return _Phase.ready;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final available = await CastService.instance.initialize();
    if (!mounted) return;
    setState(() {
      _sdkAvailable = available;
      if (available) {
        _devices = CastService.instance.devices;
        _connectedDevice = CastService.instance.currentSession?.device;
      }
    });
    if (!available) return;
    _devicesSub = CastService.instance.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    _sessionSub = CastService.instance.sessionStream.listen((session) {
      if (!mounted) return;
      final isConnected =
          session?.connectionState == GoogleCastConnectState.connected;
      setState(() => _connectedDevice = isConnected ? session?.device : null);
    });
    await CastService.instance.startDiscovery();
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }

  Future<void> _connect(GoogleCastDevice device) async {
    setState(() {
      _connecting = true;
      _connectingTo = device.friendlyName;
      _error = null;
    });
    try {
      await CastService.instance.connectAndLoad(
        device: device,
        url: widget.streamUrl(),
        title: widget.title,
        posterUrl: widget.posterUrl,
        position: widget.position?.call() ?? Duration.zero,
        duration: widget.duration?.call(),
        mediaType: widget.mediaType,
      );
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connectedDevice = device;
      });
    } on TimeoutException {
      _fail(
        '${device.friendlyName} no respondió a tiempo. Comprueba que el '
        'teléfono y el televisor estén en la misma red Wi-Fi.',
      );
    } on FormatException catch (error) {
      _fail(error.message);
    } on StateError catch (error) {
      _fail(error.message);
    } catch (error) {
      _fail('No se pudo conectar con ${device.friendlyName}. $error');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _connectingTo = null;
      _error = message;
    });
  }

  Future<void> _disconnect() async {
    try {
      await CastService.instance.disconnect();
      if (mounted) setState(() => _connectedDevice = null);
    } catch (error) {
      _fail('No se pudo desconectar: $error');
    }
  }

  Future<void> _openScreenMirroring() async {
    final res = await CastService.instance.openCastSettings();
    if (!mounted) return;
    if (!res.opened) {
      setState(() {
        _error = res.errorMessage ??
            'Este dispositivo no ofrece ninguna actividad compatible para transmitir o duplicar pantalla.';
      });
      return;
    }
    if (res.target == CastSettingsTarget.display) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se abrieron los Ajustes de pantalla como último recurso. Si tu televisor no aparece allí, consulta los ajustes de conexión de tu dispositivo.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
    // Cierra el panel de HourTV sin pausar la reproducción local.
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _black,
        border: Border(top: BorderSide(color: _red, width: 2)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 14),
              _status(),
              if (_error != null) ...[const SizedBox(height: 12), _errorBox()],
              const SizedBox(height: 10),
              ..._content(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _red.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _red.withValues(alpha: .5)),
        ),
        child: const Icon(Icons.cast_rounded, color: _red, size: 19),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transmitir',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Cerrar',
        onPressed: () => Navigator.pop(context, _connectedDevice != null),
        icon: const Icon(Icons.close_rounded, color: _muted),
      ),
    ],
  );

  Widget _status() {
    final (Color color, String text, bool spinner) = switch (_phase) {
      _Phase.unavailable => (
        _muted,
        'Google Cast no disponible en este dispositivo',
        false,
      ),
      _Phase.blocked => (
        const Color(0xFFE8A33D),
        _block?.isHeaderOrWebView == true
            ? 'Servidor con cabeceras: requiere duplicación'
            : 'Formato no compatible con Chromecast directo',
        false,
      ),
      _Phase.searching => (
        _muted,
        'Buscando dispositivos Chromecast en tu red Wi-Fi…',
        true,
      ),
      _Phase.ready => (
        _muted,
        '${_devices.length} dispositivo${_devices.length == 1 ? '' : 's'} disponible${_devices.length == 1 ? '' : 's'}',
        false,
      ),
      _Phase.connecting => (_red, 'Conectando con $_connectingTo…', true),
      _Phase.connected => (const Color(0xFF69E6B9), 'Conectado', false),
    };
    return Row(
      children: [
        if (spinner)
          SizedBox.square(
            dimension: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        else
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBox() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _red.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _red.withValues(alpha: .45)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        if (CastService.isScreenMirroringSupported(context)) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openScreenMirroring,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: _red.withValues(alpha: .6)),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            icon: const Icon(Icons.screen_share_rounded, size: 16),
            label: const Text(
              'Duplicar pantalla en su lugar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    ),
  );

  List<Widget> _content() {
    final block = _block;
    final mirroringSupported = CastService.isScreenMirroringSupported(context);

    // Si ya existe sesión conectada activa, la mostramos en primer lugar
    if (_connectedDevice != null) {
      return [
        _connectedCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_disconnect()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: _line),
                  minimumSize: const Size(0, 46),
                ),
                icon: const Icon(Icons.cast_rounded, size: 18),
                label: const Text('Desconectar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                ),
                child: const Text(
                  'Controles',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        if (mirroringSupported) ...[
          const SizedBox(height: 16),
          _sectionHeader('DUPLICAR PANTALLA'),
          const SizedBox(height: 8),
          _mirrorCard(isPrimary: false),
        ],
      ];
    }

    // Caso 1: El stream tiene bloqueo técnico (cabeceras, visor web, formato incompatible)
    if (block != null) {
      return [
        if (mirroringSupported) ...[
          _sectionHeader('OPCIÓN PRINCIPAL'),
          const SizedBox(height: 8),
          _mirrorCard(isPrimary: true),
          const SizedBox(height: 16),
        ],
        _sectionHeader('CHROMECAST DIRECTO'),
        const SizedBox(height: 8),
        _blockedExplanation(block),
      ];
    }

    // Caso 2: El stream es compatible con Chromecast directo
    return [
      _sectionHeader('TRANSMITIR CONTENIDO'),
      const SizedBox(height: 8),
      if (!_sdkAvailable) ...[
        _note(
          'Google Cast necesita los servicios de Google Play. Sin ellos no se '
          'puede enviar el contenido a un televisor por Chromecast directo.',
        ),
        if (mirroringSupported) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openScreenMirroring,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _line),
              minimumSize: const Size(0, 42),
            ),
            icon: const Icon(Icons.settings_remote_rounded, size: 18),
            label: const Text('Abrir ajustes de transmisión de Android'),
          ),
        ],
      ] else if (_devices.isEmpty) ...[
        _note(
          'Asegúrate de que el televisor o Chromecast está encendido y conectado a la misma red Wi-Fi.',
        ),
        if (mirroringSupported) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openScreenMirroring,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _line),
              minimumSize: const Size(0, 42),
            ),
            icon: const Icon(Icons.settings_remote_rounded, size: 18),
            label: const Text('Abrir ajustes de transmisión de Android'),
          ),
        ],
      ] else ...[
        for (final device in _devices) _deviceRow(device),
      ],
      if (mirroringSupported) ...[
        const SizedBox(height: 16),
        _sectionHeader('DUPLICAR PANTALLA'),
        const SizedBox(height: 8),
        _mirrorCard(isPrimary: false),
      ],
    ];
  }

  Widget _sectionHeader(String text) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    ),
  );

  Widget _mirrorCard({required bool isPrimary}) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openScreenMirroring,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary ? _red : _line,
              width: isPrimary ? 1.5 : 1.0,
            ),
            color: isPrimary ? _red.withValues(alpha: .06) : _surface,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? _red.withValues(alpha: .18)
                      : Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPrimary
                        ? _red.withValues(alpha: .4)
                        : Colors.white12,
                  ),
                ),
                child: Icon(
                  Icons.screen_share_rounded,
                  color: isPrimary ? _red : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPrimary
                          ? 'Duplicar pantalla (Recomendado)'
                          : 'Duplicar pantalla',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Refleja la pantalla en tu TV. Android te pedirá seleccionar y confirmar el televisor.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: isPrimary ? _red : _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockedExplanation(StreamBlockInfo block) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8A33D).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8A33D).withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFE8A33D),
                size: 17,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chromecast directo no disponible',
                  style: TextStyle(
                    color: Color(0xFFE8A33D),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            block.explanation,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (block.isHeaderOrWebView) ...[
            const SizedBox(height: 4),
            const Text(
              'Los receptores Chromecast no admiten cabeceras personalizadas (Referer/User-Agent). La duplicación de pantalla es la alternativa oficial para ver este contenido.',
              style: TextStyle(
                color: _muted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
    ),
  );

  Widget _connectedCard() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFF69E6B9)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.cast_connected_rounded,
          color: Color(0xFF69E6B9),
          size: 21,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _connectedDevice?.friendlyName ?? 'Dispositivo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Reproduciendo ${widget.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _deviceRow(GoogleCastDevice device) {
    final busy = _connecting && _connectingTo == device.friendlyName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: _connecting ? null : () => unawaited(_connect(device)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: busy ? _red : _line),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tv_rounded,
                  color: busy ? _red : Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.friendlyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (device.modelName?.trim().isNotEmpty ?? false)
                        Text(
                          device.modelName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _red,
                    ),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
