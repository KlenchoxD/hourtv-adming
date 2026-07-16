import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/screens/player_screen.dart';

void main() {
  test('paginas embed se detectan como no-directas', () {
    expect(isEmbedStreamUrl('https://niramirus.com/e/1echh34m2w8a'), isTrue);
    expect(isEmbedStreamUrl('https://dood.to/e/abc123'), isTrue);
    expect(isEmbedStreamUrl('https://streamtape.com/v/xyz'), isTrue);
  });

  test('streams directos NO son embed', () {
    expect(isEmbedStreamUrl('https://cdn.host/movie.mp4'), isFalse);
    expect(isEmbedStreamUrl('https://cdn.host/live/index.m3u8'), isFalse);
    expect(isEmbedStreamUrl('https://cdn.host/v.mp4?token=abc'), isFalse);
  });

  test('esquemas propios no son embed (los resuelve el reproductor)', () {
    expect(isEmbedStreamUrl('archive:identifier'), isFalse);
    expect(isEmbedStreamUrl('stalker:12345'), isFalse);
  });
}
