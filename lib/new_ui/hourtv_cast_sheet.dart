import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../models/channel.dart';
import '../services/cast_proxy.dart';
import '../services/cast_service.dart';
import '../services/dlna_service.dart';
import '../services/remote_playback.dart';

const _accent = Color(0xFF00C781);
const _bg = Color(0xFF0B0D0C);
const _surface = Color(0xFF151917);
const _line = Color(0xFF232A27);
const _muted = Color(0xFFA6A6B0);
const _warn = Color(0xFFE8A33D);

/// Panel "Transmitir a TV": busca a la vez Chromecast y Smart TV DLNA (lo que
/// usa Xuper) y envía el video al que se elija. Los videos que exigen
/// Referer/User-Agent pasan por [CastProxy], así también se pueden enviar.
///
/// Devuelve la transmisión iniciada (para abrir los controles) o null.
Future<RemotePlayback?> showCastSheet(
  BuildContext context, {
  required String title,

  /// Video a enviar; null si no hay un stream directo (solo visor web).
  required Future<CastMedia?> Function() media,
  String? posterUrl,
  Duration Function()? position,
  MediaType? mediaType,

  /// Motivo conocido de antemano por el que no se puede enviar al TV.
  String? blockedReason,
}) {
  return showModalBottomSheet<RemotePlayback>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CastSheet(
      title: title,
      media: media,
      posterUrl: posterUrl,
      position: position,
      mediaType: mediaType,
      blockedReason: blockedReason,
    ),
  );
}

class _CastSheet extends StatefulWidget {
  const _CastSheet({
    required this.title,
    required this.media,
    this.posterUrl,
    this.position,
    this.mediaType,
    this.blockedReason,
  });

  final String title;
  final Future<CastMedia?> Function() media;
  final String? posterUrl;
  final Duration Function()? position;
  final MediaType? mediaType;
  final String? blockedReason;

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

/// Un TV de la lista: Chromecast o DLNA.
class _Target {
  const _Target.google(GoogleCastDevice this.google) : dlna = null;
  const _Target.dlna(DlnaRenderer this.dlna) : google = null;

  final GoogleCastDevice? google;
  final DlnaRenderer? dlna;

  String get id => google?.deviceID ?? dlna!.id;
  String get name => google?.friendlyName ?? dlna!.name;
  String get kind {
    if (google != null) return 'Chromecast';
    final model = dlna!.model?.trim();
    return model == null || model.isEmpty ? 'Smart TV' : model;
  }
}

class _CastSheetState extends State<_CastSheet> {
  StreamSubscription<List<GoogleCastDevice>>? _googleSub;
  List<GoogleCastDevice> _google = const [];
  bool _googleSearching = false;
  String? _connectingId;
  String? _error;

  List<_Target> get _targets => [
    for (final d in _google) _Target.google(d),
    for (final d in DlnaService.instance.renderers.value) _Target.dlna(d),
  ];

  bool get _searching =>
      DlnaService.instance.searching.value || _googleSearching;

  @override
  void initState() {
    super.initState();
    DlnaService.instance.renderers.addListener(_refresh);
    DlnaService.instance.searching.addListener(_refresh);
    RemotePlayback.active.addListener(_refresh);
    if (widget.blockedReason == null) unawaited(_search());
  }

  @override
  void dispose() {
    DlnaService.instance.renderers.removeListener(_refresh);
    DlnaService.instance.searching.removeListener(_refresh);
    RemotePlayback.active.removeListener(_refresh);
    _googleSub?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    setState(() => _error = null);
    unawaited(DlnaService.instance.scan());
    if (_googleSub != null) return;
    final available = await CastService.instance.initialize();
    if (!mounted || !available) return;
    // Sesión Chromecast que ya estaba abierta (de antes o desde la
    // notificación): se muestra como transmisión en curso.
    if (CastService.instance.isConnected &&
        RemotePlayback.active.value == null) {
      RemotePlayback.active.value = GoogleCastPlayback();
    }
    setState(() {
      _google = CastService.instance.devices;
      _googleSearching = true;
    });
    _googleSub = CastService.instance.devicesStream.listen((devices) {
      if (mounted) setState(() => _google = devices);
    });
    await CastService.instance.startDiscovery();
    // Chromecast no avisa cuándo terminó de buscar: se da el mismo margen
    // que a la búsqueda DLNA.
    await Future<void>.delayed(const Duration(seconds: 6));
    if (mounted) setState(() => _googleSearching = false);
  }

  Future<void> _connect(_Target target) async {
    setState(() {
      _connectingId = target.id;
      _error = null;
    });
    try {
      final media = await widget.media();
      if (media == null) {
        throw const DlnaException(
          'No se pudo obtener un video directo de este servidor. Prueba '
          'con otro servidor.',
        );
      }
      final position = widget.position?.call() ?? Duration.zero;
      final RemotePlayback playback;
      if (target.google != null) {
        playback = await _castGoogle(target.google!, media, position);
      } else {
        playback = await _castDlna(target.dlna!, media, position);
      }
      RemotePlayback.active.value = playback;
      if (mounted) Navigator.pop(context, playback);
    } on TimeoutException {
      _fail(
        '${target.name} no respondió. Comprueba que el TV esté encendido y '
        'en la misma red Wi-Fi que el teléfono.',
      );
    } on DlnaException catch (e) {
      _fail(e.message);
    } on StateError catch (e) {
      _fail(e.message);
    } on FormatException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('No se pudo enviar el video a ${target.name}.');
    }
  }

  Future<RemotePlayback> _castGoogle(
    GoogleCastDevice device,
    CastMedia media,
    Duration position,
  ) async {
    // El receptor de Chromecast no manda cabeceras y exige CORS en HLS, que
    // casi ningún servidor IPTV permite: esos pasan por el teléfono.
    final isHls =
        CastService.contentTypeFor(media.url, mediaType: widget.mediaType) ==
        'application/x-mpegURL';
    final url = media.headers.isNotEmpty || isHls
        ? await CastProxy.instance.urlFor(media.url, media.headers)
        : media.url;
    await CastService.instance.connectAndLoad(
      device: device,
      url: url,
      title: widget.title,
      posterUrl: widget.posterUrl,
      position: position,
      mediaType: widget.mediaType,
    );
    return GoogleCastPlayback();
  }

  Future<RemotePlayback> _castDlna(
    DlnaRenderer tv,
    CastMedia media,
    Duration position,
  ) async {
    final url = media.headers.isNotEmpty
        ? await CastProxy.instance.urlFor(media.url, media.headers)
        : media.url;
    final mime =
        CastService.contentTypeFor(media.url, mediaType: widget.mediaType) ??
        'video/mp4';
    await DlnaService.instance.load(
      tv,
      url: url,
      title: widget.title,
      mimeType: mime,
      position: widget.mediaType == MediaType.live ? Duration.zero : position,
    );
    return DlnaPlayback(tv);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _connectingId = null;
      _error = message;
    });
  }

  Future<void> _openScreenMirroring() async {
    final res = await CastService.instance.openCastSettings();
    if (!mounted) return;
    if (!res.opened) {
      setState(() => _error = res.errorMessage);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final active = RemotePlayback.active.value;
    final mirroring = CastService.isScreenMirroringSupported(context);
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _header(),
              const SizedBox(height: 18),
              if (active != null)
                ..._connected(active)
              else if (widget.blockedReason != null)
                _notice(widget.blockedReason!, color: _warn)
              else
                ..._deviceList(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _notice(_error!, color: const Color(0xFFFF5A66)),
              ],
              if (mirroring && active == null) ...[
                const SizedBox(height: 18),
                const Divider(color: _line, height: 1),
                const SizedBox(height: 8),
                _mirrorRow(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      const Icon(Icons.cast_rounded, color: _accent, size: 24),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transmitir a TV',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _deviceList() {
    final targets = _targets;
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Televisores en tu Wi-Fi',
              style: TextStyle(
                color: _muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_searching)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            )
          else
            TextButton.icon(
              onPressed: _connectingId == null
                  ? () => unawaited(_search())
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Buscar de nuevo'),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (targets.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            _searching
                ? 'Buscando televisores…'
                : 'No encontramos ningún televisor. Enciende el TV y conecta '
                      'el teléfono a la misma red Wi-Fi.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.4),
          ),
        )
      else
        for (final target in targets) _deviceRow(target),
    ];
  }

  Widget _deviceRow(_Target target) {
    final busy = _connectingId == target.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _connectingId == null
              ? () => unawaited(_connect(target))
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  target.google != null ? Icons.cast_rounded : Icons.tv_rounded,
                  color: busy ? _accent : Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        busy ? 'Enviando video…' : target.kind,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: busy ? _accent : _muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _connected(RemotePlayback active) => [
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cast_connected_rounded, color: _accent, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Transmitiendo',
                  style: TextStyle(color: _accent, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => unawaited(active.disconnect()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _line),
              minimumSize: const Size(0, 46),
            ),
            child: const Text('Desconectar'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.pop(context, active),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
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
  ];

  Widget _notice(String text, {required Color color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _mirrorRow() => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: _openScreenMirroring,
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.screen_share_rounded, color: Colors.white, size: 22),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicar pantalla',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Refleja todo el teléfono en el TV desde Android',
                  style: TextStyle(color: _muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    ),
  );
}
