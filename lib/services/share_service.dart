import 'dart:io';

import 'package:flutter/services.dart';

enum DetailShareResult { shared, copied }

class ShareService {
  static const _channel = MethodChannel('hourtv/device');

  static Future<DetailShareResult> shareVod({
    required String title,
    String? plot,
  }) async {
    final synopsis = plot?.trim();
    final text = synopsis == null || synopsis.isEmpty
        ? title.trim()
        : '${title.trim()}\n\n$synopsis';

    if (Platform.isAndroid) {
      try {
        final shared = await _channel.invokeMethod<bool>('shareText', {
          'subject': title.trim(),
          'text': text,
        });
        if (shared == true) return DetailShareResult.shared;
      } on PlatformException {
        // El portapapeles mantiene disponible la acción en Android sin handler.
      } on MissingPluginException {
        // También permite usar esta pantalla en escritorio y durante pruebas.
      }
    }

    await Clipboard.setData(ClipboardData(text: text));
    return DetailShareResult.copied;
  }
}
