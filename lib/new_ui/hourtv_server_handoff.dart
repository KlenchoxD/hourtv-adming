import 'package:flutter/material.dart';

/// One native-player handoff layer: poster and server wheel fade out together
/// only after the player has produced advancing, non-buffering playback.
class HourTvServerHandoff extends StatelessWidget {
  final List<String> names;
  final int activeIndex;
  final bool ready;
  final Widget? artwork;

  const HourTvServerHandoff({
    super.key,
    required this.names,
    required this.activeIndex,
    required this.ready,
    this.artwork,
  });

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty && artwork == null) return const SizedBox.shrink();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: reduceMotion ? 0 : 280);
    final active = names.isEmpty
        ? 0
        : activeIndex.clamp(0, names.length - 1).toInt();
    final nameCounts = <String, int>{};
    for (final name in names) {
      nameCounts.update(name, (count) => count + 1, ifAbsent: () => 1);
    }

    return IgnorePointer(
      child: AnimatedOpacity(
        key: const ValueKey('hourtv-server-handoff-fade'),
        opacity: ready ? 0 : 1,
        duration: duration,
        curve: Curves.easeInOutCubic,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (artwork != null)
              Positioned.fill(child: RepaintBoundary(child: artwork!)),
            if (names.isNotEmpty)
              RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, size) {
                    final height = size.hasBoundedHeight
                        ? size.maxHeight
                        : 720.0;
                    final step = (height * .18).clamp(92.0, 140.0).toDouble();
                    const rowHeight = 84.0;
                    final wheelHeight = step * 2 + rowHeight;
                    final first = (active - 2)
                        .clamp(0, names.length - 1)
                        .toInt();
                    final last = (active + 2)
                        .clamp(0, names.length - 1)
                        .toInt();

                    return Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: size.maxWidth * .06),
                        child: SizedBox(
                          width: (size.maxWidth * .36)
                              .clamp(160.0, 290.0)
                              .toDouble(),
                          height: wheelHeight,
                          child: LayoutBuilder(
                            builder: (context, wheelSize) => ClipRect(
                              child: Stack(
                                children: [
                                  for (
                                    var index = first;
                                    index <= last;
                                    index++
                                  )
                                    _ServerWheelCandidate(
                                      key: ValueKey(index),
                                      index: index,
                                      name: nameCounts[names[index]]! > 1
                                          ? '${names[index]} · ${index + 1}'
                                          : names[index],
                                      active: index == active,
                                      visible: (index - active).abs() <= 1,
                                      ready: ready,
                                      top:
                                          wheelSize.maxHeight / 2 -
                                          rowHeight / 2 +
                                          (index - active) * step,
                                      height: rowHeight,
                                      duration: duration,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServerWheelCandidate extends StatelessWidget {
  final int index;
  final String name;
  final bool active;
  final bool visible;
  final bool ready;
  final double top;
  final double height;
  final Duration duration;

  const _ServerWheelCandidate({
    super.key,
    required this.index,
    required this.name,
    required this.active,
    required this.visible,
    required this.ready,
    required this.top,
    required this.height,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      key: ValueKey('server-wheel-slot-$index'),
      duration: duration,
      curve: Curves.easeInOutCubic,
      left: 0,
      right: 0,
      top: top,
      height: height,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? (active ? 1 : .46) : 0,
          duration: duration,
          curve: Curves.easeInOutCubic,
          child: AnimatedScale(
            scale: active ? 1 : .88,
            duration: duration,
            curve: Curves.easeInOutCubic,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontSize: MediaQuery.sizeOf(context).width < 500 ? 19 : 24,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 14,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        !active
                            ? 'En espera'
                            : ready
                            ? 'Conectado'
                            : 'Conectando…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: active
                              ? Colors.white70
                              : Colors.white.withValues(alpha: .5),
                          fontSize: 13,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 10,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (active && !ready) ...[
                      const SizedBox(width: 9),
                      const RepaintBoundary(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.4,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
