import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:streamtv/services/video_format_hint.dart';

void main() {
  group('videoFormatHintFor', () {
    test('recognizes HLS path when signed query parameters are present', () {
      expect(
        videoFormatHintFor(
          Uri.parse('https://cdn.example/master.m3u8?token=abc&expires=123'),
        ),
        VideoFormat.hls,
      );
    });

    test('recognizes an HLS MIME type when URL path is opaque', () {
      expect(
        videoFormatHintFor(
          Uri.parse('https://cdn.example/play?id=123'),
          contentType: 'application/vnd.apple.mpegurl; charset=utf-8',
        ),
        VideoFormat.hls,
      );
    });

    test('prefers an explicit validated resolver format for opaque URLs', () {
      expect(
        videoFormatHintFor(
          Uri.parse('https://cdn.example/play?id=123'),
          formatHint: 'dash',
        ),
        VideoFormat.dash,
      );
      expect(
        videoFormatHintFor(
          Uri.parse('https://cdn.example/play?id=123'),
          formatHint: 'unknown',
        ),
        isNull,
      );
    });

    test('recognizes DASH and Smooth Streaming manifests', () {
      expect(
        videoFormatHintFor(Uri.parse('https://cdn.example/movie.mpd?sig=x')),
        VideoFormat.dash,
      );
      expect(
        videoFormatHintFor(Uri.parse('https://cdn.example/live.ism/manifest')),
        VideoFormat.ss,
      );
      expect(
        videoFormatHintFor(
          Uri.parse('https://cdn.example/play'),
          contentType: 'application/dash+xml',
        ),
        VideoFormat.dash,
      );
    });

    test('does not force a format for files or ambiguous paths', () {
      expect(
        videoFormatHintFor(Uri.parse('https://cdn.example/movie.mp4?token=x')),
        isNull,
      );
      expect(
        videoFormatHintFor(Uri.parse('https://cdn.example/play?file=.m3u8')),
        isNull,
      );
    });

    test('rejects malformed or unsafe URLs', () {
      expect(videoFormatHintFor(Uri.parse('file:///movie.m3u8')), isNull);
      expect(
        videoFormatHintFor(Uri.parse('https://user:pass@cdn.example/a.m3u8')),
        isNull,
      );
      expect(videoFormatHintFor(Uri.parse('https:///a.m3u8')), isNull);
    });
  });
}
