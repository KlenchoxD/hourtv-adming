import 'package:flutter/material.dart';

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
    if (!controlsVisible) {
      return isBuffering
          ? const Center(child: _BufferingIndicator())
          : const SizedBox.shrink();
    }
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Control(
            icon: Icons.replay_10_rounded,
            label: 'Retroceder 10 segundos',
            onTap: onSeekBackward,
          ),
          const SizedBox(width: 36),
          // Same footprint in both states; no layered pause icon and spinner.
          if (isBuffering)
            const _BufferingIndicator()
          else
            _Control(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              label: isPlaying ? 'Pausar' : 'Reproducir',
              size: 76,
              filled: true,
              onTap: onTogglePlayback,
            ),
          const SizedBox(width: 36),
          _Control(
            icon: Icons.forward_10_rounded,
            label: 'Adelantar 10 segundos',
            onTap: onSeekForward,
          ),
        ],
      ),
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
      color: filled ? const Color(0x33FFFFFF) : Colors.transparent,
      shape: CircleBorder(
        side: filled
            ? const BorderSide(color: Color(0x55FFFFFF))
            : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: Colors.white, size: size * .56),
        ),
      ),
    ),
  );
}
