import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Reproductor del servidor (paulinito, voe, ok.ru...) dentro de un iframe.
/// Es la única forma sin servidor intermedio: esos videos exigen que la
/// petición venga de su propia página, y el navegador no deja fingirlo.
Widget hourTvEmbedFrame(String url) => HtmlElementView.fromTagName(
  key: ValueKey(url),
  tagName: 'iframe',
  onElementCreated: (element) {
    final frame = element as web.HTMLIFrameElement
      ..src = url
      ..allow = 'autoplay; fullscreen; picture-in-picture; encrypted-media'
      ..allowFullscreen = true
      ..referrerPolicy = 'origin';
    // Sin "allow-popups" el reproductor no puede abrir pestañas de
    // publicidad. Solo donde se comprobó que igual reproduce: voe y
    // streamwish detectan el sandbox y se niegan a mostrar el video.
    if (_sandboxOk(url)) {
      frame.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-presentation allow-forms',
      );
    }
    frame.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = 'black';
  },
);

const _sandboxHosts = {'paulinito.com', 'ok.ru'};

bool _sandboxOk(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return _sandboxHosts.any((h) => host == h || host.endsWith('.$h'));
}

/// Video directo (canales en vivo .m3u8, .mp4) con el reproductor del
/// navegador: Chrome, Edge y Safari ya reproducen HLS solos, y sin
/// "crossorigin" no hace falta que el canal permita CORS.
Widget hourTvVideoFrame(String url, {VoidCallback? onError}) =>
    HtmlElementView.fromTagName(
      key: ValueKey('video:$url'),
      tagName: 'video',
      onElementCreated: (element) {
        final video = element as web.HTMLVideoElement
          ..src = url
          ..controls = true
          ..autoplay = true
          ..playsInline = true
          // Sin el botón de "transmitir" que Chrome de Android dibuja encima.
          ..disableRemotePlayback = true;
        video.style
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'black'
          ..objectFit = 'contain';
        if (onError != null) {
          video.addEventListener('error', ((web.Event _) => onError()).toJS);
        }
      },
    );
