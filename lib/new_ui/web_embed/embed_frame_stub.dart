import 'package:flutter/widgets.dart';

/// Fuera del navegador no hay iframes: la app nativa usa su reproductor.
Widget hourTvEmbedFrame(String url) => const SizedBox.shrink();

Widget hourTvVideoFrame(String url, {VoidCallback? onError}) =>
    const SizedBox.shrink();

Widget hourTvPointerShield(Widget child) => child;
