import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../services/cast_service.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

/// Panel de transmision propio de HourTV.
///
/// Sustituye al panel nativo de Android (`Settings.ACTION_CAST_SETTINGS`), que
/// sacaba al usuario de la app y no encajaba con nada. Aqui se busca, se
/// selecciona, se ve el estado y se puede desconectar sin salir.
///
/// Devuelve `true` si quedo una sesion conectada, para que quien lo abrio
/// pueda pausar el video local y mostrar los controles remotos.
Future<bool> showCastSheet(
  BuildContext context, {
  required String title,
  required String Function() streamUrl,
  String? posterUrl,
  Duration Function()? position,
  Duration? Function()? duration,

  /// Motivo por el que este contenido no se puede transmitir, si aplica. Se
  /// muestra en lugar de la lista: es mas honesto que ofrecer dispositivos a
  /// los que el envio va a fallar.
  String? blockedReason,
}) async {
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
      blockedReason: blockedReason,
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
    this.blockedReason,
  });

  final String title;
  final String Function() streamUrl;
  final String? posterUrl;
  final Duration Function()? position;
  final Duration? Function()? duration;
  final String? blockedReason;

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

  _Phase get _phase {
    if (!_sdkAvailable) return _Phase.unavailable;
    if (_connectedDevice != null) return _Phase.connected;
    if (_connecting) return _Phase.connecting;
    if (widget.blockedReason != null) return _Phase.blocked;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 14),
            _status(),
            if (_error != null) ...[const SizedBox(height: 12), _errorBox()],
            const SizedBox(height: 6),
            ..._content(),
          ],
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
        onPressed: () => Navigator.pop(context, _connectedDevice != null),
        icon: const Icon(Icons.close_rounded, color: _muted),
      ),
    ],
  );

  /// Estado de conexion, siempre visible: es lo primero que se pregunta al
  /// pulsar transmitir.
  Widget _status() {
    final (Color color, String text, bool spinner) = switch (_phase) {
      _Phase.unavailable => (
        _muted,
        'Este dispositivo no tiene Google Cast',
        false,
      ),
      _Phase.blocked => (
        const Color(0xFFE8A33D),
        'No se puede transmitir',
        false,
      ),
      _Phase.searching => (_muted, 'Buscando dispositivos en tu red…', true),
      _Phase.ready => (
        _muted,
        '${_devices.length} dispositivo${_devices.length == 1 ? '' : 's'} disponible${_devices.length == 1 ? '' : 's'}',
        false,
      ),
      _Phase.connecting => (_red, 'Conectando con $_connectingTo…', true),
      _Phase.connected => (const Color(0xFF3ED98A), 'Conectado', false),
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
    child: Row(
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
  );

  List<Widget> _content() => switch (_phase) {
    _Phase.unavailable => [
      _note(
        'Google Cast necesita los servicios de Google Play. Sin ellos no se '
        'puede enviar el contenido a un televisor desde este teléfono.',
      ),
    ],
    _Phase.blocked => [_note(widget.blockedReason!)],
    _Phase.connected => [
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
    ],
    _Phase.searching => [
      _note(
        'Asegúrate de que el televisor o Chromecast está encendido y en la '
        'misma red Wi-Fi que este teléfono.',
      ),
    ],
    _Phase.connecting ||
    _Phase.ready => [for (final device in _devices) _deviceRow(device)],
  };

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
      border: Border.all(color: const Color(0xFF3ED98A)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.cast_connected_rounded,
          color: Color(0xFF3ED98A),
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
