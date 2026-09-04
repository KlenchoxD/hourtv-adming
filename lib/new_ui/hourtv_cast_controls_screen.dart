import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../services/cast_service.dart';

const _black = Color(0xFF000000);
const _surface = Color(0xFF111113);
const _line = Color(0xFF2A2A2E);
const _muted = Color(0xFFA6A6B0);
const _red = Color(0xFF00C781);

/// Controles Chromecast con el lenguaje visual rojo/negro de HourTV.
class CastControlsScreen extends StatefulWidget {
  const CastControlsScreen({
    super.key,
    required this.title,
    this.fallbackDuration = Duration.zero,
  });

  final String title;
  final Duration fallbackDuration;

  @override
  State<CastControlsScreen> createState() => _CastControlsScreenState();
}

class _CastControlsScreenState extends State<CastControlsScreen> {
  StreamSubscription<GoogleCastSession?>? _sessionSubscription;
  StreamSubscription<GoggleCastMediaStatus?>? _statusSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  GoogleCastSession? _session;
  GoggleCastMediaStatus? _status;
  Duration _position = Duration.zero;
  double _volume = .5;
  bool _disconnecting = false;

  @override
  void initState() {
    super.initState();
    final sessions = GoogleCastSessionManager.instance;
    final media = GoogleCastRemoteMediaClient.instance;
    _session = sessions.currentSession;
    _status = media.mediaStatus;
    _position = media.playerPosition;
    _volume = (_session?.currentDeviceVolume ?? .5).clamp(0, 1);
    _sessionSubscription = sessions.currentSessionStream.listen((session) {
      if (!mounted) return;
      if (session == null && !_disconnecting) {
        Navigator.maybePop(context, true);
        return;
      }
      setState(() {
        _session = session;
        _volume = (session?.currentDeviceVolume ?? _volume).clamp(0, 1);
      });
    });
    _statusSubscription = media.mediaStatusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });
    _positionSubscription = media.playerPositionStream.listen((position) {
      if (mounted) setState(() => _position = position);
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _statusSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Duration get _duration =>
      _status?.mediaInformation?.duration ?? widget.fallbackDuration;

  bool get _playing =>
      _status?.playerState == CastMediaPlayerState.playing ||
      _status?.playerState == CastMediaPlayerState.buffering ||
      _status?.playerState == CastMediaPlayerState.loading;

  String get _stateLabel => switch (_status?.playerState) {
    CastMediaPlayerState.playing => 'Reproduciendo',
    CastMediaPlayerState.paused => 'Pausado',
    CastMediaPlayerState.buffering => 'Cargando',
    CastMediaPlayerState.loading => 'Cargando',
    CastMediaPlayerState.idle => 'Detenido',
    _ => 'Conectado',
  };

  Future<void> _toggle() async {
    final media = GoogleCastRemoteMediaClient.instance;
    _playing ? await media.pause() : await media.play();
  }

  Future<void> _seek(Duration target) async {
    final max = _duration.inMilliseconds;
    final value = target.inMilliseconds.clamp(0, max > 0 ? max : 0);
    await GoogleCastRemoteMediaClient.instance.seek(
      GoogleCastMediaSeekOption(position: Duration(milliseconds: value)),
    );
  }

  Future<void> _disconnect() async {
    _disconnecting = true;
    await CastService.instance.disconnect();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = _duration.inMilliseconds;
    final positionMs = _position.inMilliseconds.clamp(
      0,
      durationMs > 0 ? durationMs : 0,
    );
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Transmitiendo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Desconectar',
            onPressed: _disconnect,
            icon: const Icon(Icons.cast_connected_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _line),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
                  child: Column(
                    children: [
                      Container(
                        width: 94,
                        height: 94,
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: .12),
                          shape: BoxShape.circle,
                          border: Border.all(color: _red.withValues(alpha: .4)),
                        ),
                        child: const Icon(
                          Icons.cast_connected_rounded,
                          color: _red,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_session?.device?.friendlyName ?? 'Chromecast'} · $_stateLabel',
                        style: const TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 28),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _red,
                          thumbColor: _red,
                          inactiveTrackColor: _line,
                        ),
                        child: Slider(
                          value: durationMs > 0 ? positionMs.toDouble() : 0,
                          max: durationMs > 0 ? durationMs.toDouble() : 1,
                          onChanged: durationMs > 0
                              ? (value) => setState(
                                  () => _position = Duration(
                                    milliseconds: value.round(),
                                  ),
                                )
                              : null,
                          onChangeEnd: durationMs > 0
                              ? (value) =>
                                    _seek(Duration(milliseconds: value.round()))
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_format(_position)),
                            Text(_format(_duration)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _control(
                            Icons.replay_10_rounded,
                            () =>
                                _seek(_position - const Duration(seconds: 10)),
                            label: 'Retroceder 10 segundos',
                          ),
                          const SizedBox(width: 20),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: _red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(68, 68),
                            ),
                            iconSize: 40,
                            tooltip: _playing ? 'Pausar' : 'Reproducir',
                            onPressed: _toggle,
                            icon: Icon(
                              _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                          const SizedBox(width: 20),
                          _control(
                            Icons.forward_10_rounded,
                            () =>
                                _seek(_position + const Duration(seconds: 10)),
                            label: 'Adelantar 10 segundos',
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          const Icon(Icons.volume_down_rounded, color: _muted),
                          Expanded(
                            child: Slider(
                              value: _volume,
                              activeColor: _red,
                              onChanged: (value) {
                                setState(() => _volume = value);
                                GoogleCastSessionManager.instance
                                    .setDeviceVolume(value);
                              },
                            ),
                          ),
                          const Icon(Icons.volume_up_rounded, color: _muted),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _line),
                        ),
                        onPressed: GoogleCastRemoteMediaClient.instance.stop,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Detener reproducción'),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: _red),
                        onPressed: _disconnect,
                        icon: const Icon(Icons.cast_connected_rounded),
                        label: const Text('Desconectar del TV'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _control(
    IconData icon,
    VoidCallback onPressed, {
    required String label,
  }) => IconButton(
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xFF1C1C1F),
      foregroundColor: Colors.white,
      minimumSize: const Size(52, 52),
    ),
    tooltip: label,
    onPressed: onPressed,
    icon: Icon(icon),
  );

  String _format(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
