import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_web_live_policy.dart';

void main() {
  final policy = HourTvWebLivePolicy.instance;
  const old = 'https://example.com/dead.m3u8';
  const target = 'https://${HourTvWebLivePolicy.relayHost}/live/iptv-123.m3u8';
  final hash = sha256.convert(utf8.encode(old)).toString();
  tearDown(() => policy.apply({'version': 1}));
  test('removes only audited live URLs, never movies', () {
    policy.apply({
      'version': 1,
      'excludedUrlHashes': [hash],
    });
    expect(
      policy.retain(Channel(name: 'Dead', url: old, forcedType: 'live')),
      isFalse,
    );
    expect(
      policy.retain(
        Channel(name: 'Working', url: 'https://example.com/ok.m3u8'),
      ),
      isTrue,
    );
    expect(
      policy.retain(Channel(name: 'Movie', url: old, forcedType: 'movie')),
      isTrue,
    );
  });
  test(
    'replacement preserves the old identity and only changes web playback',
    () {
      final channel = Channel(
        name: 'Original',
        url: old,
        forcedType: 'live',
        isFavorite: true,
      );
      policy.apply({
        'version': 1,
        'excludedUrlHashes': [hash],
        'replacements': {hash: target},
      });
      expect(policy.retain(channel), isTrue);
      expect(policy.playbackReplacement(channel), target);
      expect(channel.url, old);
      expect(channel.isFavorite, isTrue);
    },
  );
  test('rejects caller-controlled hosts and malformed removals atomically', () {
    policy.apply({'version': 1});
    expect(
      () => policy.apply({
        'version': 1,
        'excludedUrlHashes': ['bad'],
      }),
      throwsFormatException,
    );
    expect(
      () => policy.apply({
        'version': 1,
        'replacements': {hash: 'https://evil.test/x'},
      }),
      throwsFormatException,
    );
    expect(policy.excludedHashes, isEmpty);
    expect(policy.replacements, isEmpty);
  });
  test(
    'deduplicates imported cards while preserving old favourite identities',
    () {
      final original = Channel(
        name: 'Original',
        url: old,
        forcedType: 'live',
        isFavorite: true,
      );
      final imported = Channel(
        name: 'Imported',
        url: target,
        forcedType: 'live',
      );
      policy.apply({
        'version': 1,
        'replacements': {hash: target},
      });
      expect(policy.filter([imported, original]), [original]);
      expect(policy.filter([imported]), [imported]);
    },
  );
}
