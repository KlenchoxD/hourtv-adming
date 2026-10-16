import 'dart:async';

import 'extraction_engine.dart';
import 'local_hls_proxy.dart';
import 'webflux_manifest_capture.dart';

export 'webflux_manifest_capture.dart'
    show WebfluxCapturedManifest, WebfluxManifestCapture;

class WebfluxResolutionCancelled implements Exception {
  const WebfluxResolutionCancelled();
}

class WebfluxResolutionException implements Exception {
  const WebfluxResolutionException({required this.retryable});
  final bool retryable;
}

/// One resolver per playback session: cancellation cannot destroy the proxy
/// belonging to a different player. Successful sessions live until disposeAll.
class WebfluxStreamResolver {
  WebfluxStreamResolver({
    WebfluxManifestCapture? capture,
    LocalHlsProxy Function()? createProxy,
  }) : _capture = capture ?? HeadlessWebfluxManifestCapture(),
       _createProxy = createProxy ?? LocalHlsProxy.new;

  final WebfluxManifestCapture _capture;
  final LocalHlsProxy Function() _createProxy;
  final _cancelled = Completer<void>();
  LocalHlsProxy? _proxy;
  bool _disposed = false;
  Future<void>? _disposing;

  static bool supports(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.toLowerCase() == 'webflux.vip' &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(uri.fragment);

  Future<String> resolveToLocalM3u8(
    String embedUrl, {
    ExtractionRequest? request,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final embed = Uri.parse(embedUrl);
    if (!supports(embed)) throw const UnsupportedExtractionException();
    if (_disposed || request?.isCancelled == true) {
      throw const WebfluxResolutionCancelled();
    }
    // The cancellation future is observed before an immediate request.cancel().
    final work = Future<String>.sync(() async {
      final manifest = await _capture.capture(embed);
      await _capture.close();
      if (_disposed) throw const WebfluxResolutionCancelled();
      final proxy = _createProxy();
      _proxy = proxy;
      final uri = await proxy.start(
        manifest.uri,
        headers: manifest.headers,
        cookiesFor: manifest.cookiesFor,
      );
      if (_disposed) throw const WebfluxResolutionCancelled();
      return uri.toString();
    });
    final result = Future.any<String>([
      work,
      _cancelled.future.then((_) => throw const WebfluxResolutionCancelled()),
    ]);
    request?.addCancellationHandler(disposeAll);
    try {
      return await result.timeout(timeout);
    } catch (error) {
      await disposeAll();
      if (error is FormatException) {
        throw const WebfluxResolutionException(retryable: false);
      }
      if (error is HlsUpstreamException) {
        throw WebfluxResolutionException(
          retryable:
              error.statusCode == 408 ||
              error.statusCode == 425 ||
              error.statusCode == 429 ||
              error.statusCode >= 500,
        );
      }
      rethrow;
    } finally {
      request?.removeCancellationHandler(disposeAll);
    }
  }

  Future<void> disposeAll() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
    try {
      await _capture.close();
    } finally {
      await _proxy?.close();
      _proxy = null;
    }
  }
}
