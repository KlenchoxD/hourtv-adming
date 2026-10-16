import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamtv/services/extraction_engine.dart';
import 'package:streamtv/services/local_hls_proxy.dart';
import 'package:streamtv/services/webflux_stream_resolver.dart';
import 'package:streamtv/services/webflux_manifest_capture.dart';
import 'package:streamtv/services/embed_resolver.dart';
import 'package:video_player/video_player.dart';

class _Capture implements WebfluxManifestCapture {
  final pending = Completer<WebfluxCapturedManifest>();
  bool closed = false;
  @override
  Future<WebfluxCapturedManifest> capture(Uri embed) => pending.future;
  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  test(
    'successful capture waits for native startup acknowledgment before handoff',
    () async {
      final capture = Completer<String>();
      final startup = Completer<void>();
      var returned = false;
      final result = observeWebfluxCaptureStartup(
        capture: capture.future,
        startup: startup.future,
        onStartupComplete: () async {},
      );
      final completion = result.then((value) {
        returned = true;
        return value;
      });
      capture.complete('local-hls');
      await Future<void>.delayed(Duration.zero);
      expect(returned, isFalse);
      startup.complete();
      expect(await completion, 'local-hls');
    },
  );
  test(
    'capture cancellation is observed while native WebView startup is pending',
    () async {
      final capture = Completer<String>();
      final startup = Completer<void>();
      var cleanedUp = false;
      final result = observeWebfluxCaptureStartup(
        capture: capture.future,
        startup: startup.future,
        onStartupComplete: () async {
          cleanedUp = true;
        },
      );
      final checked = expectLater(result, throwsA(isA<StateError>()));
      capture.completeError(StateError('cancelled'));
      await checked;
      expect(cleanedUp, isFalse);
      startup.complete();
      await Future<void>.delayed(Duration.zero);
      expect(cleanedUp, isTrue);
    },
  );

  test(
    'a startup failure leaves later capture cancellation observed',
    () async {
      final capture = Completer<String>();
      final startup = Completer<void>();
      final result = observeWebfluxCaptureStartup(
        capture: capture.future,
        startup: startup.future,
        onStartupComplete: () async {},
      );
      final checked = expectLater(result, throwsA(isA<StateError>()));
      startup.completeError(StateError('native startup failed'));
      await checked;
      capture.completeError(StateError('cleanup cancellation'));
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'manifest capture recognizes token parameters regardless of their order',
    () {
      expect(
        HeadlessWebfluxManifestCapture.isManifestRequest(
          Uri.parse('https://cdn.test/index-f1-v1-a1.txt?kx=2&k=1'),
        ),
        isTrue,
      );
      expect(
        HeadlessWebfluxManifestCapture.isManifestRequest(
          Uri.parse('https://cdn.test/cf-master.123.txt?k=1'),
        ),
        isTrue,
      );
      expect(
        HeadlessWebfluxManifestCapture.isManifestRequest(
          Uri.parse('https://cdn.test/font.woff2?k=1'),
        ),
        isFalse,
      );
      expect(
        HeadlessWebfluxManifestCapture.isManifestRequest(
          Uri.parse('https://ads.test/advertisement.m3u8'),
        ),
        isFalse,
      );
    },
  );

  test(
    'a missing upstream manifest is terminal instead of an endless network retry',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final capture = _Capture();
      final resolver = WebfluxStreamResolver(
        capture: capture,
        createProxy: () => LocalHlsProxy(
          client: MockClient((_) async => http.Response('missing', 404)),
        ),
      );
      addTearDown(resolver.disposeAll);
      capture.pending.complete(
        WebfluxCapturedManifest(
          Uri.parse('https://cdn.test/index-f1.txt?k=1'),
          const {},
        ),
      );
      final result = await EmbedResolver.resolveForPlayback(
        'https://webflux.vip/#fixture',
        webfluxResolver: resolver,
      );
      expect(result.stream, isNull);
      expect(result.terminalFailure, isTrue);
      expect(result.retryableFailure, isFalse);
    },
  );
  test(
    'closing an unused capture or resolver does not emit an unhandled error',
    () async {
      await HeadlessWebfluxManifestCapture().close();
      await WebfluxStreamResolver(capture: _Capture()).disposeAll();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'the Webflux adapter returns a releasable HLS source before generic extractors',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final capture = _Capture();
      final resolver = WebfluxStreamResolver(
        capture: capture,
        createProxy: () => LocalHlsProxy(
          client: MockClient(
            (_) async => http.Response('#EXTM3U\n#EXTINF:5,\nseg.woff2\n', 200),
          ),
        ),
      );
      addTearDown(resolver.disposeAll);
      capture.pending.complete(
        WebfluxCapturedManifest(
          Uri.parse('https://cdn.test/index-f1.txt?k=1'),
          const {},
        ),
      );
      final result = await EmbedResolver.resolveForPlayback(
        'https://webflux.vip/#m9euzc',
        webfluxResolver: resolver,
      );
      expect(result.stream, isNotNull);
      expect(result.stream!.formatHint, VideoFormat.hls);
      final local = Uri.parse(result.stream!.url);
      expect((await http.get(local)).statusCode, 200);
      await result.stream!.release!();
      await expectLater(http.get(local), throwsA(isA<http.ClientException>()));
    },
  );
  test('recognizes only the Webflux embed host and complete hash', () {
    expect(
      WebfluxStreamResolver.supports(Uri.parse('https://webflux.vip/#m9euzc')),
      isTrue,
    );
    expect(
      WebfluxStreamResolver.supports(Uri.parse('https://other.test/#m9euzc')),
      isFalse,
    );
    expect(
      WebfluxStreamResolver.supports(
        Uri.parse('https://webflux.vip.evil.test/#m9euzc'),
      ),
      isFalse,
    );
    expect(
      WebfluxStreamResolver.supports(Uri.parse('https://webflux.vip/')),
      isFalse,
    );
  });

  test(
    'request cancellation stops the hidden resolver and discards late results',
    () async {
      final capture = _Capture();
      final resolver = WebfluxStreamResolver(capture: capture);
      addTearDown(resolver.disposeAll);
      final request = ExtractionRequest();
      final future = resolver.resolveToLocalM3u8(
        'https://webflux.vip/#m9euzc',
        request: request,
      );
      final assertion = expectLater(
        future,
        throwsA(isA<WebfluxResolutionCancelled>()),
      );
      request.cancel();
      await assertion;
      expect(capture.closed, isTrue);
      capture.pending.complete(
        WebfluxCapturedManifest(
          Uri.parse('https://cdn.test/index-f1.txt?k=1'),
          const {},
        ),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('capture closes before the native HLS session is returned', () async {
    final capture = _Capture();
    final resolver = WebfluxStreamResolver(
      capture: capture,
      createProxy: () => LocalHlsProxy(
        client: MockClient(
          (_) async => http.Response('#EXTM3U\n#EXTINF:5,\nseg.woff2\n', 200),
        ),
      ),
    );
    addTearDown(resolver.disposeAll);
    final future = resolver.resolveToLocalM3u8('https://webflux.vip/#m9euzc');
    capture.pending.complete(
      WebfluxCapturedManifest(
        Uri.parse('https://cdn.test/index-f1.txt?k=1'),
        const {},
      ),
    );
    final url = Uri.parse(await future);
    expect(url.host, '127.0.0.1');
    expect(url.path, endsWith('/stream.m3u8'));
    expect(capture.closed, isTrue);
    final response = await http.get(url);
    expect(response.statusCode, 200);
    await resolver.disposeAll();
    await expectLater(http.get(url), throwsA(isA<http.ClientException>()));
  });
}
