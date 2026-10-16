import 'package:flutter/material.dart';
import 'hourtv_mobile_player_chrome.dart';

/// Presentation only: buffering never changes playback or control visibility.
/// The caller owns the tap-to-show/auto-hide policy and the video controller.
class HourTvPlaybackCenter extends StatelessWidget {
  const HourTvPlaybackCenter({
    super.key,
    required this.controlsVisible,
    required this.isBuffering,
    required this.isPlaying,
    required this.onTogglePlayback,
    required this.onSeekBackward,
    required this.onSeekForward,
  });

  final bool controlsVisible;
  final bool isBuffering;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;

  @override
  Widget build(BuildContext context) {
    final controls = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Control(
            icon: Icons.replay_10_rounded,
            label: 'Retroceder 10 segundos',
            onTap: onSeekBackward,
          ),
          const SizedBox(width: 28),
          // Same footprint in both states; no layered pause icon and spinner.
          if (isBuffering)
            const SizedBox.square(dimension: 76)
          else
            _Control(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              label: isPlaying ? 'Pausar' : 'Reproducir',
              size: 76,
              filled: true,
              onTap: onTogglePlayback,
            ),
          const SizedBox(width: 28),
          _Control(
            icon: Icons.forward_10_rounded,
            label: 'Adelantar 10 segundos',
            onTap: onSeekForward,
          ),
        ],
      ),
    );
    // The spinner has its own lifecycle: hiding the chrome fades seek buttons
    // without fading, duplicating or recreating the buffering indicator.
    // Replacing the primary button with a spacer is synchronous, so pause can
    // never remain underneath a spinner during a transition.
    return Stack(
      children: [
        Positioned.fill(
          child: PlayerChromeVisibility(
            visible: controlsVisible,
            child: controls,
          ),
        ),
        if (isBuffering) const Center(child: _BufferingIndicator()),
      ],
    );
  }
}

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: 'Cargando vídeo',
      child: RepaintBoundary(
        // Keep the rotating painter in its own small layer, not in the layer
        // containing subtitles, the gradient and the entire transport bar.
        child: SizedBox.square(
          dimension: 76,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0x99000000),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox.square(
                dimension: 36,
                child: CircularProgressIndicator(
                  color: Color(0xFF00C781),
                  strokeWidth: 3.2,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 52,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Container(
              width: filled ? size - 10 : size,
              height: filled ? size - 10 : size,
              decoration: BoxDecoration(
                color: filled ? const Color(0xFFF6F4EF) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: filled ? const Color(0xFF101412) : Colors.white,
                size: filled ? 34 : 30,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
