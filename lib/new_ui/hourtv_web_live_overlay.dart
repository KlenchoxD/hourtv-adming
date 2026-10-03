import 'package:flutter/material.dart';
import 'hourtv_web_feedback.dart';

/// Web-only live controls. The program indicator is not a seek bar.
class HourTvWebLiveOverlay extends StatelessWidget {
  const HourTvWebLiveOverlay({
    super.key,
    required this.channel,
    required this.currentTitle,
    this.currentTime,
    this.nextTitle,
    this.nextTime,
    required this.playing,
    required this.ready,
    required this.volume,
    required this.fullscreen,
    required this.onPause,
    required this.onMute,
    required this.onVolume,
    required this.onFullscreen,
  });
  final String channel, currentTitle;
  final String? currentTime, nextTitle, nextTime;
  final bool playing, ready, fullscreen;
  final double volume;
  final VoidCallback onPause, onMute, onFullscreen;
  final ValueChanged<double> onVolume;
  static const green = Color(0xFF00C781);

  Widget _button(String label, IconData icon, VoidCallback? action) =>
      HourTvWebFeedback(
        child: IconButton(
          tooltip: label,
          onPressed: action,
          icon: Icon(icon, color: Colors.white),
          style: IconButton.styleFrom(hoverColor: Colors.white12),
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 600;
      return Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .45, 1],
                    colors: [
                      Color(0x18000000),
                      Colors.transparent,
                      Color(0xEE000000),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: green, size: 8),
                  SizedBox(width: 8),
                  Text(
                    'EN VIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 16 : 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          if (currentTime?.isNotEmpty == true)
                            Text(
                              currentTime!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!compact && nextTitle?.isNotEmpty == true)
                      Container(
                        width: 200,
                        padding: const EdgeInsets.only(left: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.white24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'A continuación',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nextTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            if (nextTime?.isNotEmpty == true)
                              Text(
                                nextTime!,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: Colors.white24),
                Row(
                  children: [
                    _button(
                      playing ? 'Pausar' : 'Reanudar',
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      ready ? onPause : null,
                    ),
                    _button(
                      volume == 0 ? 'Activar sonido' : 'Silenciar',
                      volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      ready ? onMute : null,
                    ),
                    if (!compact)
                      SizedBox(
                        width: 120,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 4,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                          ),
                          child: Slider(
                            value: volume,
                            activeColor: green,
                            inactiveColor: Colors.white24,
                            onChanged: ready ? onVolume : null,
                          ),
                        ),
                      ),
                    const Spacer(),
                    const Icon(Icons.circle, color: green, size: 7),
                    const SizedBox(width: 7),
                    const Text(
                      'EN VIVO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _button(
                      fullscreen
                          ? 'Salir de pantalla completa'
                          : 'Pantalla completa',
                      fullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      onFullscreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
