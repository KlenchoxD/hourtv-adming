import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Pantalla completa de verdad y horizontal: el botón de cada servidor
/// dentro del iframe no siempre deja (Chrome de Android lo bloquea).
void hourTvToggleFullscreen() {
  final document = web.document;
  if (document.fullscreenElement != null) {
    unawaited(document.exitFullscreen().toDart.catchError((_) => null));
    return;
  }
  final root = document.documentElement;
  if (root == null) return;
  unawaited(
    root
        .requestFullscreen()
        .toDart
        .then((_) async {
          // Solo existe en celulares; en computador falla y no importa.
          try {
            await web.window.screen.orientation.lock('landscape').toDart;
          } catch (_) {}
        })
        .catchError((_) {}),
  );
}

bool hourTvIsFullscreen() => web.document.fullscreenElement != null;
