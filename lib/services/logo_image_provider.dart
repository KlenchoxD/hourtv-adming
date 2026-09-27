import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'content_fingerprint.dart';

/// Logo de canal con caché en disco propia, como Glide en Xuper: un archivo
/// por URL (nombre = hash), sin base de datos. flutter_cache_manager hacía
/// consultas y escrituras en SQLite en el hilo de la interfaz por cada logo
/// (incluso ya cacheado) y trababa el scroll rápido de TV en vivo.
///
/// Lectura, descarga y escritura son IO asíncrono (fuera del hilo de la
/// interfaz); la decodificación la hace el motor en sus propios hilos.
// ponytail: sin límite ni limpieza del directorio; los logos pesan pocos KB.
// Agregar una poda por fecha si la carpeta crece de más.
@immutable
class LogoImageProvider extends ImageProvider<LogoImageProvider> {
  const LogoImageProvider(this.url);

  final String url;

  @visibleForTesting
  static Directory? debugCacheDir;
  static Future<Directory>? _dir;

  static Future<Directory> _cacheDir() {
    if (debugCacheDir != null) return Future.value(debugCacheDir);
    return _dir ??= getTemporaryDirectory().then((base) async {
      final dir = Directory('${base.path}${Platform.pathSeparator}logos');
      await dir.create(recursive: true);
      return dir;
    });
  }

  /// Archivo en disco de [url] (existe solo si ya se descargó).
  @visibleForTesting
  static Future<File> fileFor(String url) async {
    final dir = await _cacheDir();
    final name = fingerprintString(url).toUnsigned(64).toRadixString(16);
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  @override
  Future<LogoImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<LogoImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    LogoImageProvider key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: url,
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await loadBytes(url);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  /// Bytes del logo: del disco si ya está, si no de la red (y se guardan).
  @visibleForTesting
  static Future<Uint8List> loadBytes(String url, {http.Client? client}) async {
    final file = await fileFor(url);
    try {
      final cached = await file.readAsBytes();
      if (cached.isNotEmpty) return cached;
    } on FileSystemException {
      // No está en disco todavía.
    }
    final response =
        await (client?.get(Uri.parse(url)) ?? http.get(Uri.parse(url))).timeout(
          const Duration(seconds: 15),
        );
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: Uri.parse(url),
      );
    }
    // Se escribe aparte con archivo temporal + rename: una lectura a medias
    // nunca ve un logo cortado.
    final bytes = response.bodyBytes;
    unawaited(() async {
      try {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(file.path);
      } catch (_) {}
    }());
    return bytes;
  }

  @override
  bool operator ==(Object other) =>
      other is LogoImageProvider && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
