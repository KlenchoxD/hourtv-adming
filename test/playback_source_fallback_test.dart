import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/playback_source_fallback.dart';

void main() {
  test('orders preferred source, primary URL and mirrors without duplicates', () {
    final channel = Channel(
      name: 'Movie',
      url: 'https://primary.test/video.m3u8',
      servers: const [
        ChannelServer(name: 'Mirror A', url: 'https://mirror-a.test/video.m3u8'),
        ChannelServer(name: 'Primary duplicate', url: 'https://primary.test/video.m3u8'),
        ChannelServer(name: 'Empty', url: ''),
      ],
    );

    final plan = PlaybackSourcePlan.forChannel(
      channel,
      preferredUrl: 'https://mirror-a.test/video.m3u8',
    );

    expect(plan.current, 'https://mirror-a.test/video.m3u8');
    expect(plan.advance(), 'https://primary.test/video.m3u8');
    expect(plan.advance(), isNull);
  });

  test('falls back through each available source once', () {
    final channel = Channel(
      name: 'Channel',
      url: 'https://primary.test/live',
      servers: const [
        ChannelServer(name: 'Mirror A', url: 'https://mirror-a.test/live'),
        ChannelServer(name: 'Mirror B', url: 'https://mirror-b.test/live'),
      ],
    );

    final plan = PlaybackSourcePlan.forChannel(channel);
    expect(plan.current, 'https://primary.test/live');
    expect(plan.hasNext, isTrue);
    expect(plan.advance(), 'https://mirror-a.test/live');
    expect(plan.advance(), 'https://mirror-b.test/live');
    expect(plan.hasNext, isFalse);
    expect(plan.advance(), isNull);
  });
}