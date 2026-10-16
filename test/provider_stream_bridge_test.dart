import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:streamtv/services/embed_resolver.dart';
import 'package:streamtv/services/extraction_engine.dart';
import 'package:streamtv/services/provider_stream_bridge.dart';
import 'package:streamtv/services/subtitles/hourtv_subtitle_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hourtv/provider_stream');
  const moonGetterChannel = MethodChannel('hourtv/moongetter');
  const ytChannel = MethodChannel('hourtv/yt_dlp');
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(moonGetterChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ytChannel, null);
  });

  test(
    'MoonGetter direct HLS result preserves safe playback headers',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(moonGetterChannel, (call) async {
            expect(call.method, 'resolve');
            return {
              'status': 'resolved',
              'url': 'https://cdn.test/master.m3u8?sig=short-lived',
              'formatHint': 'hls',
              'headers': {
                'Referer': 'https://streamwish.test/e/episode',
                'User-Agent': 'HourTV',
                'Cookie': 'never-forward-this',
                'X-Private': 'discard',
              },
              'subtitles': <Map<String, Object>>[],
            };
          });

      final result = await EmbedResolver.resolveForPlayback(
        'https://streamwish.test/e/episode',
      );

      expect(
        result.stream?.url,
        'https://cdn.test/master.m3u8?sig=short-lived',
      );
      expect(result.stream?.formatHint, VideoFormat.hls);
      expect(
        result.stream?.headers['Referer'],
        'https://streamwish.test/e/episode',
      );
      expect(result.stream?.headers['User-Agent'], 'HourTV');
      expect(result.stream?.headers.containsKey('Cookie'), isFalse);
      expect(result.stream?.headers.containsKey('X-Private'), isFalse);
    },
  );

  test(
    'recognized MoonGetter failure stops same-page extractors for mirror fallback',
    () async {
      var resolutionCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(moonGetterChannel, (_) async {
            resolutionCalls++;
            return {'status': 'failed'};
          });

      final result = await EmbedResolver.resolveForPlayback(
        'https://streamwish.test/e/unavailable',
      );

      expect(resolutionCalls, 1);
      expect(result.stream, isNull);
      expect(result.terminalFailure, isTrue);
    },
  );

  test(
    'transient MoonGetter network failure is eligible for recovery',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(moonGetterChannel, (_) async {
            return {'status': 'failed', 'retryable': true};
          });

      final result = await EmbedResolver.resolveForPlayback(
        'https://streamwish.test/e/temporary-network-failure',
      );

      expect(result.stream, isNull);
      expect(result.retryableFailure, isTrue);
      expect(result.terminalFailure, isFalse);
    },
  );

  test('canceling a MoonGetter extraction uses its request ID', () async {
    final started = Completer<void>();
    final cancellationSeen = Completer<void>();
    final nativeResponse = Completer<Map<String, dynamic>?>();
    final requestId = ProviderStreamBridge.newResolverRequestId();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(moonGetterChannel, (call) async {
          if (call.method == 'resolve') {
            expect(call.arguments['requestId'], requestId);
            started.complete();
            return nativeResponse.future;
          }
          if (call.method == 'cancel') {
            expect(call.arguments['requestId'], requestId);
            cancellationSeen.complete();
            nativeResponse.complete({'status': 'cancelled'});
            return null;
          }
          fail('Unexpected method ${call.method}');
        });

    final pending = ProviderStreamBridge.resolveMoonGetter(
      'https://streamwish.test/e/episode',
      requestId: requestId,
    );
    await started.future.timeout(const Duration(seconds: 1));
    await ProviderStreamBridge.cancelMoonGetter(requestId);

    expect(await pending, isNull);
    await cancellationSeen.future.timeout(const Duration(seconds: 1));
  });

  test(
    'unrecognized host can continue to existing extraction adapters',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            moonGetterChannel,
            (_) async => {'status': 'unsupported'},
          );
      final result = await ProviderStreamBridge.resolveMoonGetter(
        'https://custom-owned-host.test/watch/1',
      );
      expect(result?.recognized, isFalse);
      expect(result?.stream, isNull);
    },
  );

  test('local yt-dlp adapter uses its own native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ytChannel, (call) async {
          expect(call.method, 'resolve');
          expect(call.arguments['url'], 'https://provider.test/e/1');
          return {
            'url': 'https://cdn.test/master.m3u8',
            'headers': <String, String>{},
            'formatHint': 'hls',
          };
        });
    final source = await ProviderStreamBridge.resolveYtDlp(
      'https://provider.test/e/1',
    );
    expect(source?.url, 'https://cdn.test/master.m3u8');
    expect(source?.formatHint, VideoFormat.hls);
  });

  test('canceling yt-dlp resolves only its matching request ID', () async {
    final started = Completer<void>();
    final cancellationSeen = Completer<void>();
    final nativeResponse = Completer<Map<String, dynamic>?>();
    final requestId = ProviderStreamBridge.newResolverRequestId();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ytChannel, (call) async {
          if (call.method == 'resolve') {
            expect(call.arguments['requestId'], requestId);
            started.complete();
            return nativeResponse.future;
          }
          if (call.method == 'cancel') {
            expect(call.arguments['requestId'], requestId);
            cancellationSeen.complete();
            nativeResponse.complete(null);
            return null;
          }
          fail('Unexpected method ${call.method}');
        });

    final pending = ProviderStreamBridge.resolveYtDlp(
      'https://provider.test/e/episode',
      requestId: requestId,
    );
    await started.future.timeout(const Duration(seconds: 1));
    await ProviderStreamBridge.cancelYtDlp(requestId);

    expect(await pending, isNull);
    await cancellationSeen.future.timeout(const Duration(seconds: 1));
  });

  test(
    'specialized byse resolver runs before generic adapters and cancels by request id',
    () async {
      final resolutionStarted = Completer<void>();
      final cancellationSeen = Completer<void>();
      final pending = Completer<Map<String, dynamic>?>();
      final events = <String>[];
      int? requestId;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(moonGetterChannel, (call) async {
            events.add('moongetter');
            return {'status': 'unsupported'};
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'resolve') {
              events.add('byse-resolve');
              requestId = call.arguments['requestId'] as int;
              resolutionStarted.complete();
              return pending.future;
            }
            if (call.method == 'cancel') {
              events.add('byse-cancel');
              expect(call.arguments['requestId'], requestId);
              cancellationSeen.complete();
              return null;
            }
            fail('Unexpected method ${call.method}');
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ytChannel, (_) async {
            events.add('yt-dlp');
            return null;
          });

      final request = ExtractionRequest();
      final resolving = EmbedResolver.resolveForPlayback(
        'https://byseraguci.com/e/test',
        request: request,
      );
      await resolutionStarted.future.timeout(const Duration(seconds: 1));
      request.cancel();
      final result = await resolving.timeout(const Duration(seconds: 1));
      await cancellationSeen.future.timeout(const Duration(seconds: 1));
      pending.complete(null);

      expect(result.stream, isNull);
      expect(events, ['moongetter', 'byse-resolve', 'byse-cancel']);
    },
  );

  test(
    'passes observed source and required headers to native playback',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'resolve');
            return {
              'url': 'https://cdn.test/master.m3u8',
              'headers': {
                'Referer': 'https://provider.test/',
                'Cookie': 'must-not-cross-platform-boundary',
                'X-Arbitrary': 'discard',
                'User-Agent': 'HourTV',
              },
              'formatHint': 'hls',
              'subtitles': [
                {
                  'url': 'https://cdn.test/es.vtt?sig=x',
                  'language': 'es',
                  'ext': 'vtt',
                  'headers': {
                    'User-Agent': 'HourTV',
                    'Cookie': 'must-not-cross-platform-boundary',
                  },
                },
              ],
            };
          });
      final source = await ProviderStreamBridge.resolve(
        'https://byseraguci.com/e/test',
      );
      expect(source?.url, 'https://cdn.test/master.m3u8');
      expect(source?.headers['Referer'], 'https://provider.test/');
      expect(source?.headers['User-Agent'], 'HourTV');
      expect(source?.headers.containsKey('Cookie'), isFalse);
      expect(source?.headers.containsKey('X-Arbitrary'), isFalse);
      expect(source?.formatHint, VideoFormat.hls);
      expect(source?.subtitleTracks, hasLength(1));
      expect(source?.subtitleTracks.single.languageCode, 'es');
      expect(source?.subtitleTracks.single.format, SubtitleFormat.vtt);
      expect(
        source?.subtitleTracks.single.requiredHeaders['User-Agent'],
        'HourTV',
      );
      expect(
        source?.subtitleTracks.single.requiredHeaders.containsKey('Cookie'),
        isFalse,
      );
    },
  );

  test('drops unsafe or unsupported subtitle metadata', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {
            'url': 'https://cdn.test/master.m3u8',
            'headers': <String, String>{},
            'subtitles': [
              {'url': 'http://cdn.test/es.vtt', 'language': 'es', 'ext': 'vtt'},
              {
                'url': 'https://cdn.test/es.bin',
                'language': 'es',
                'ext': 'bin',
              },
              {
                'url': 'https://cdn.test/bad.vtt',
                'language': 'xx\r\n',
                'ext': 'vtt',
              },
            ],
          },
        );
    final source = await ProviderStreamBridge.resolve(
      'https://byseraguci.com/e/test',
    );
    expect(source?.subtitleTracks, isEmpty);
  });

  for (final value in [
    null,
    {'url': 42},
    {'headers': <String, String>{}},
    {'url': 'blob:https://provider.test/id'},
    {'url': 'http://cdn.test/master.m3u8'},
    {'url': 'https://user@cdn.test/master.m3u8'},
  ]) {
    test(
      'unusable source remains eligible for next-server fallback: $value',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => value);
        expect(
          await ProviderStreamBridge.resolve('https://byseraguci.com/e/test'),
          isNull,
        );
      },
    );
  }
}
