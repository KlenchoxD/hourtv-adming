import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebfluxCapturedManifest {
  const WebfluxCapturedManifest(this.uri, this.headers, {this.cookiesFor});
  final Uri uri;
  final Map<String, String> headers;
  final Future<String?> Function(Uri)? cookiesFor;
}

/// Observe both asynchronous paths immediately. A cancelled capture must not
/// leave an unobserved failure while a platform method-channel start is pending.
/// The startup continuation also cleans up a view created after cancellation.
Future<T> observeWebfluxCaptureStartup<T>({
  required Future<T> capture,
  required Future<void> startup,
  required Future<void> Function() onStartupComplete,
}) {
  final started = startup.then((_) => onStartupComplete());
  return Future.any<T>([
    // Successful media capture needs a fully created view so close() can
    // actually dispose it. Failures/cancellation still propagate immediately.
    capture.then((value) async {
      await started;
      return value;
    }),
    started.then((_) => capture),
  ]);
}

abstract interface class WebfluxManifestCapture {
  Future<WebfluxCapturedManifest> capture(Uri embed);
  Future<void> close();
}

/// Observes the media request made by the normal embed page. It is never
/// mounted in the app's widget tree and is stopped before native playback.
class HeadlessWebfluxManifestCapture implements WebfluxManifestCapture {
  HeadlessInAppWebView? _view;
  bool _closed = false;
  final _cancelled = Completer<void>();

  @override
  Future<WebfluxCapturedManifest> capture(Uri embed) async {
    if (_closed) throw StateError('Manifest capture closed');
    // The plugin otherwise logs intercepted request arguments, including signed
    // playlist URLs. HourTV emits only its own sanitized provider diagnostics.
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
    final found = Completer<WebfluxCapturedManifest>();
    final userAgent = await InAppWebViewController.getDefaultUserAgent();
    if (_closed) throw StateError('Manifest capture closed');
    final view = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(embed.toString())),
      initialSettings: InAppWebViewSettings(
        userAgent: userAgent,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        useShouldInterceptRequest: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: false,
        allowFileAccess: false,
        allowContentAccess: false,
      ),
      shouldOverrideUrlLoading: (_, action) async {
        final uri = action.request.url;
        if (uri == null ||
            uri.scheme != 'https' ||
            action.isForMainFrame && uri.host != embed.host) {
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      shouldInterceptRequest: (_, request) async {
        final uri = Uri.tryParse(request.url.toString());
        if (_closed ||
            found.isCompleted ||
            uri == null ||
            !isManifestRequest(uri)) {
          return null;
        }
        final headers = <String, String>{
          'User-Agent': userAgent,
          'Origin': embed.origin,
          'Referer': '${embed.origin}/',
          for (final entry
              in (request.headers ?? const <String, String>{}).entries)
            if (const [
              'origin',
              'referer',
              'user-agent',
            ].contains(entry.key.toLowerCase()))
              entry.key: entry.value,
        };
        found.complete(
          WebfluxCapturedManifest(
            uri,
            headers,
            cookiesFor: (target) async {
              // Query the browser jar for each exact target so Domain/Path/Secure
              // selection survives a redirect or a separate key/subtitle path.
              final cookies = await CookieManager.instance().getCookies(
                url: WebUri(target.toString()),
              );
              return cookies.isEmpty
                  ? null
                  : cookies.map((c) => '${c.name}=${c.value}').join('; ');
            },
          ),
        );
        // No embed video is downloaded or played while the native player starts.
        return WebResourceResponse(
          statusCode: 204,
          reasonPhrase: 'No Content',
          data: Uint8List(0),
        );
      },
      onLoadStop: (controller, _) async {
        if (_closed || found.isCompleted) return;
        await controller.evaluateJavascript(
          source: '''
          (() => {
            if (window.__hourtvPlayProbe) return;
            let attempts = 0;
            const start = () => {
              const player = document.querySelector('media-player, video');
              if (player && typeof player.play === 'function') {
                player.muted = true;
                Promise.resolve(player.play()).catch(() => {});
              }
              if (++attempts >= 30) clearInterval(window.__hourtvPlayProbe);
            };
            window.__hourtvPlayProbe = setInterval(start, 400);
            start();
          })();
        ''',
        );
      },
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true && !found.isCompleted && !_closed) {
          found.completeError(StateError('Embed page failed to load'));
        }
      },
    );
    _view = view;
    // Observe cancellation before starting the platform operation.
    final result = Future.any<WebfluxCapturedManifest>([
      found.future,
      _cancelled.future.then(
        (_) => throw StateError('Manifest capture cancelled'),
      ),
    ]);
    return observeWebfluxCaptureStartup(
      capture: result,
      startup: Future<void>.sync(view.run),
      onStartupComplete: () async {
        if (_closed) await view.dispose();
      },
    );
  }

  static bool isManifestRequest(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.host.isNotEmpty &&
      uri.queryParameters.containsKey('k') &&
      (uri.path.endsWith('.m3u8') ||
          RegExp(r'/(?:cf-master[^/]*|index-[^/]*)\.txt$').hasMatch(uri.path));

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
    final view = _view;
    _view = null;
    try {
      await view?.webViewController?.stopLoading();
    } finally {
      await view?.dispose();
    }
  }
}
