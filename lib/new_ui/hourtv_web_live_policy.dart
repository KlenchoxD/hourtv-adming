import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../models/channel.dart';

/// Audited web-only additions/removals. Never rewrites the shared mobile
/// catalogue or publishes the purchased provider's credentials.
class HourTvWebLivePolicy {
  HourTvWebLivePolicy._();
  static final instance = HourTvWebLivePolicy._();
  static const relayHost =
      'hourtv-live-relay.hourtv-release-20261002.workers.dev';
  final _hashCache = <String, String>{};
  Set<String> excludedHashes = const {};
  Map<String, String> replacements = const {};
  List<Channel> channels = const [];
  Future<void>? _loading;

  String _hash(String url) => _hashCache.putIfAbsent(
    url,
    () => sha256.convert(utf8.encode(url)).toString(),
  );

  Future<void> load() => _loading ??= () async {
    try {
      apply(
        jsonDecode(
              await rootBundle.loadString('assets/data/web_live_policy.json'),
            )
            as Map<String, dynamic>,
      );
    } catch (_) {
      // A missing or corrupt optional policy must not erase working channels.
    }
  }();

  void apply(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('Invalid policy');
    bool validHash(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
    bool relayUrl(String value) {
      final url = Uri.tryParse(value);
      return url?.scheme == 'https' &&
          url?.host == relayHost &&
          url!.query.isEmpty &&
          RegExp(r'^/live/iptv-[0-9]+\.m3u8$').hasMatch(url.path);
    }

    final excluded = <String>{};
    for (final item in json['excludedUrlHashes'] as List? ?? const []) {
      if (item is! String || !validHash(item)) {
        throw const FormatException('Invalid exclusion');
      }
      excluded.add(item);
    }
    final mapped = <String, String>{};
    for (final entry in (json['replacements'] as Map? ?? const {}).entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          !validHash(entry.key as String) ||
          !relayUrl(entry.value as String)) {
        throw const FormatException('Invalid replacement');
      }
      mapped[entry.key as String] = entry.value as String;
    }
    final additions = <Channel>[];
    final seen = <String>{};
    for (final row in json['channels'] as List? ?? const []) {
      if (row is! Map ||
          row['name'] is! String ||
          row['url'] is! String ||
          !relayUrl(row['url'] as String)) {
        throw const FormatException('Invalid web channel');
      }
      if (!seen.add(row['url'] as String)) continue;
      additions.add(
        Channel(
          name: row['name'] as String,
          url: row['url'] as String,
          tvgId: row['tvgId'] as String?,
          logo: row['logo'] as String?,
          group: row['group'] as String?,
          genre: row['genre'] as String?,
          category: 'live',
          forcedType: 'live',
          categories: List<String>.from(row['categories'] as List? ?? const []),
        ),
      );
    }
    excludedHashes = Set.unmodifiable(excluded);
    replacements = Map.unmodifiable(mapped);
    channels = List.unmodifiable(additions);
    _hashCache.clear();
  }

  bool retain(Channel channel) =>
      channel.type != MediaType.live ||
      replacements.containsKey(_hash(channel.url)) ||
      !excludedHashes.contains(_hash(channel.url));

  String? playbackReplacement(Channel channel) =>
      channel.type == MediaType.live ? replacements[_hash(channel.url)] : null;

  List<Channel> filter(List<Channel> input) {
    final retained = input.where(retain).toList();
    final targets = retained
        .map(playbackReplacement)
        .whereType<String>()
        .toSet();
    // Keep the original favourite/EPG identity instead of a duplicate card.
    return retained.where((channel) => !targets.contains(channel.url)).toList();
  }
}
