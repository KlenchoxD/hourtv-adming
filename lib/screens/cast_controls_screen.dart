import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../services/cast_service.dart';
import '../theme/app_theme.dart';

class CastControlsScreen extends StatefulWidget {
  final String title;
  final Duration fallbackDuration;

  const CastControlsScreen({
    super.key,
    required this.title,
    this.fallbackDuration = Duration.zero,
  });

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
  double _volume = 0.5;
  bool _disconnecting = false;

  @override
  void initState() {
    super.initState();
    final sessions = GoogleCastSessionManager.instance;
    final media = GoogleCastRemoteMediaClient.instance;
    _session = sessions.currentSession;
    _status = media.mediaStatus;
    _position = media.playerPosition;
    _volume = (_session?.currentDeviceVolume ?? 0.5).clamp(0.0, 1.0);
    _sessionSubscription = sessions.currentSessionStream.listen((session) {
      if (!mounted) return;
      if (session == null && !_disconnecting) {
        Navigator.maybePop(context, true);
        return;
      }
      setState(() {
        _session = session;
        _volume = (session?.currentDeviceVolume ?? _volume).clamp(0.0, 1.0);
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

  bool get _isPlaying =>
      _status?.playerState == CastMediaPlayerState.playing ||
      _status?.playerState == CastMediaPlayerState.buffering ||
      _status?.playerState == CastMediaPlayerState.loading;

  Future<void> _togglePlayback() async {
    final media = GoogleCastRemoteMediaClient.instance;
    _isPlaying ? await media.pause() : await media.play();
  }

  Future<void> _seek(Duration target) async {
    final duration = _duration;
    final maxMs = duration.inMilliseconds;
    final clamped = target.inMilliseconds.clamp(0, maxMs > 0 ? maxMs : 0);
    await GoogleCastRemoteMediaClient.instance.seek(
      GoogleCastMediaSeekOption(position: Duration(milliseconds: clamped)),
    );
  }

  Future<void> _stop() async {
    await GoogleCastRemoteMediaClient.instance.stop();
  }

  Future<void> _disconnect() async {
    _disconnecting = true;
    await CastService.instance.disconnect();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration;
    final durationMs = duration.inMilliseconds;
    final positionMs = _position.inMilliseconds.clamp(
      0,
      durationMs > 0 ? durationMs : 0,
    );
    final stateLabel = switch (_status?.playerState) {
      CastMediaPlayerState.playing => 'Reproduciendo',
      CastMediaPlayerState.paused => 'Pausado',
      CastMediaPlayerState.buffering => 'Cargando',
      CastMediaPlayerState.loading => 'Cargando',
      CastMediaPlayerState.idle => 'Detenido',
      _ => 'Conectado',
    };
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: const Text('Transmitiendo'),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cast_connected_rounded,
                    color: AppColors.accent,
                    size: 76,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_session?.device?.friendlyName ?? 'Chromecast'} · $stateLabel',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  Slider(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_format(_position)),
                        Text(_format(duration)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Retroceder 10 segundos',
                        onPressed: () =>
                            _seek(_position - const Duration(seconds: 10)),
                        icon: const Icon(Icons.replay_10_rounded),
                      ),
                      const SizedBox(width: 20),
                      IconButton.filled(
                        tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
                        iconSize: 42,
                        onPressed: _togglePlayback,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton.filledTonal(
                        tooltip: 'Adelantar 10 segundos',
                        onPressed: () =>
                            _seek(_position + const Duration(seconds: 10)),
                        icon: const Icon(Icons.forward_10_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.volume_down_rounded),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          onChanged: (value) {
                            setState(() => _volume = value);
                            GoogleCastSessionManager.instance.setDeviceVolume(
                              value,
                            );
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up_rounded),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Detener reproducción'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
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
    );
  }

  String _format(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
