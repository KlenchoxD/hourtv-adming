import 'dart:async';

import 'package:flutter/material.dart';
import '../services/remote_playback.dart';

const _black = Color(0xFF000000);
const _surface = Color(0xFF111113);
const _line = Color(0xFF2A2A2E);
const _muted = Color(0xFFA6A6B0);
const _red = Color(0xFF00C781);

/// Controles del video que se ve en el TV (Chromecast o DLNA).
class CastControlsScreen extends StatefulWidget {
  const CastControlsScreen({
    super.key,
    required this.title,
    required this.playback,
  });

  final String title;
  final RemotePlayback playback;

  @override
  State<CastControlsScreen> createState() => _CastControlsScreenState();
}

class _CastControlsScreenState extends State<CastControlsScreen> {
  RemotePlayback get _p => widget.playback;

  // Posición mientras se arrastra la barra (se busca al soltar).
  Duration? _dragging;

  @override
  void initState() {
    super.initState();
    _p.addListener(_refresh);
    RemotePlayback.active.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    _p.removeListener(_refresh);
    RemotePlayback.active.removeListener(_onActiveChanged);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // La transmisión terminó (desconectada aquí, desde el TV o la notificación).
  void _onActiveChanged() {
    if (mounted && !identical(RemotePlayback.active.value, _p)) {
      Navigator.maybePop(context, true);
    }
  }

  Duration get _duration => _p.duration;
  Duration get _position => _dragging ?? _p.position;
  bool get _playing => _p.playing;
  String get _stateLabel => _p.stateLabel;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El televisor no respondió.')),
      );
    }
  }

  Future<void> _toggle() => _run(_p.togglePlay);

  Future<void> _seek(Duration target) {
    final max = _duration.inMilliseconds;
    final value = target.inMilliseconds.clamp(0, max > 0 ? max : 0);
    return _run(() => _p.seek(Duration(milliseconds: value)));
  }

  Future<void> _disconnect() async {
    await _run(_p.disconnect);
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
                        '${_p.deviceName} · $_stateLabel',
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
                                  () => _dragging = Duration(
                                    milliseconds: value.round(),
                                  ),
                                )
                              : null,
                          onChangeEnd: durationMs > 0
                              ? (value) {
                                  setState(() => _dragging = null);
                                  _seek(Duration(milliseconds: value.round()));
                                }
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
                      if (_p.volume != null) ...[
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            const Icon(
                              Icons.volume_down_rounded,
                              color: _muted,
                            ),
                            Expanded(
                              child: Slider(
                                value: _p.volume!,
                                activeColor: _red,
                                onChanged: (value) =>
                                    unawaited(_run(() => _p.setVolume(value))),
                              ),
                            ),
                            const Icon(Icons.volume_up_rounded, color: _muted),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _line),
                        ),
                        onPressed: () => unawaited(_run(_p.stop)),
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
