import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/playback_engine_fallback_policy.dart';

void main() {
  group('PlaybackEngineFallbackPolicy', () {
    test('recognizes a format failure inside Media3 source-error wrapping', () {
      expect(
        PlaybackEngineFallbackPolicy.shouldTryMpv(
          'ExoPlaybackException: Source error; caused by UnrecognizedInputFormatException',
        ),
        isTrue,
      );
      expect(
        PlaybackEngineFallbackPolicy.shouldTryMpv(
          'Source error; UnrecognizedInputFormatException; HTTP 403',
        ),
        isFalse,
      );
    });
    test('routes unsupported containers to the alternate native engine', () {
      expect(
        PlaybackEngineFallbackPolicy.shouldTryMpv(
          'UnrecognizedInputFormatException: None of the available extractors',
        ),
        isTrue,
      );
    });

    test('routes decoder initialization failures to the alternate engine', () {
      expect(
        PlaybackEngineFallbackPolicy.shouldTryMpv(
          'MediaCodecRenderer\$DecoderInitializationException: decoder init failed',
        ),
        isTrue,
      );
    });

    test('does not hide HTTP authorization or server failures', () {
      for (final error in [
        'HTTP 403 Forbidden',
        'HttpDataSourceException: response code: 404',
        'HTTP 401 Unauthorized; DecoderInitializationException',
      ]) {
        expect(
          PlaybackEngineFallbackPolicy.shouldTryMpv(error),
          isFalse,
          reason: error,
        );
      }
    });

    test('does not use the engine fallback for connectivity failures', () {
      for (final error in [
        'SocketException: Failed host lookup',
        'TimeoutException: request timed out',
        'ExoPlaybackException: Source error',
      ]) {
        expect(
          PlaybackEngineFallbackPolicy.shouldTryMpv(error),
          isFalse,
          reason: error,
        );
      }
    });

    test('unknown failures remain eligible for source-level handling only', () {
      expect(
        PlaybackEngineFallbackPolicy.shouldTryMpv(
          'PlatformException: playback failed',
        ),
        isFalse,
      );
    });
  });
}
