import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_web_live_sources.dart';

void main() {
  test(
    'reemplaza solo los RCN incompatibles sin cambiar identidad ni favoritos',
    () {
      final original = Channel(
        name: 'RCN HD2 (1080p)',
        url: 'http://old.example/live.m3u8',
        isFavorite: true,
        forcedType: 'live',
      );
      expect(
        hourTvWebLivePlaybackUrl(original),
        endsWith('/live/rcn-hd2.m3u8'),
      );
      expect(original.url, 'http://old.example/live.m3u8');
      expect(original.isFavorite, isTrue);
      for (final name in ['RCN Novelas', 'Noticias RCN', 'A Spor']) {
        final c = Channel(
          name: name,
          url: 'https://active.example/live.m3u8',
          forcedType: 'live',
        );
        expect(hourTvWebLivePlaybackUrl(c), c.url);
      }
      final movie = Channel(
        name: 'Canal RCN',
        url: 'movie:1',
        forcedType: 'movie',
      );
      expect(hourTvWebLivePlaybackUrl(movie), movie.url);
    },
  );
}
