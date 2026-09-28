import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/hls_variants.dart';

void main() {
  test('lista una calidad por altura, de mayor a menor', () {
    const manifest = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
360/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
https://cdn.example/1080.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
720/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720
720b/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=64000,CODECS="mp4a.40.2"
audio.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=854x480,AUDIO="aac"
480/index.m3u8
''';
    final variants = parseHlsVariants(
      manifest,
      Uri.parse('https://host.example/movie/master.m3u8?t=1'),
    );
    expect(variants.map((v) => v.label), ['1080p', '720p', '360p']);
    expect(variants[0].url, 'https://cdn.example/1080.m3u8');
    expect(variants[1].url, 'https://host.example/movie/720b/index.m3u8');
    expect(variants[2].url, 'https://host.example/movie/360/index.m3u8');
  });

  test('una playlist de medios no tiene calidades', () {
    const media = '#EXTM3U\n#EXTINF:6.0,\nseg0.ts\n';
    expect(parseHlsVariants(media, Uri.parse('https://h/x.m3u8')), isEmpty);
  });
}
