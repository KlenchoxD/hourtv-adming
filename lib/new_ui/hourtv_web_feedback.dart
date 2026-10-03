import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HourTvWebFeedback extends StatefulWidget {
  const HourTvWebFeedback({super.key, required this.child});
  final Widget child;
  @override
  State<HourTvWebFeedback> createState() => _FeedbackState();
}

class _FeedbackState extends State<HourTvWebFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  bool hover = false, pressed = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() {
        hover = false;
        pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => pressed = true),
        onPointerCancel: (_) => setState(() => pressed = false),
        onPointerUp: (_) {
          setState(() => pressed = false);
          if (!reduced) controller.forward(from: 0);
        },
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final pulse = controller.isAnimating
                ? (1 - controller.value) * .09
                : 0.0;
            return AnimatedScale(
              scale: reduced
                  ? 1
                  : pressed
                  ? .9
                  : (hover ? 1.04 : 1) + pulse,
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
