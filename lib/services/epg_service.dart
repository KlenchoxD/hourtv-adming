import 'dart:convert';
import 'dart:io' show gzip;

import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/epg_program.dart';

class EpgService {
  static const int maxSourcesPerLoad = 24;
  static final Map<String, List<EpgProgram>> _guide = {};

  static Future<void> attachNowNext(
    List<Channel> channels,
    List<String> epgUrls,
  ) async {
    if (channels.isEmpty || epgUrls.isEmpty) return;

    final wanted = _wantedKeys(channels);
    if (wanted.isEmpty) return;

    final now = DateTime.now().toUtc();
    final selectedUrls = _prioritizeUrls(
      epgUrls,
      channels,
    ).take(maxSourcesPerLoad).toList();

    for (final url in selectedUrls) {
      try {
        final xml = await _fetchXml(url);
        final programs = _parsePrograms(xml, wanted, now);
        if (programs.isEmpty) continue;
        _mergeGuide(programs);
        _attach(channels, programs, now);
        if (_allMatched(channels)) return;
      } catch (_) {
        // Una guia EPG publica puede fallar o estar temporalmente vacia.
        // Seguimos con las demas para no bloquear la carga de canales.
      }
    }
  }

  static List<EpgProgram> programsFor(Channel channel) {
    final merged = <EpgProgram>[];
    for (final key in _keysForChannel(channel)) {
      final programs = _guide[key];
      if (programs != null) merged.addAll(programs);
    }
    if (merged.isEmpty) {
      if (channel.currentProgram != null) merged.add(channel.currentProgram!);
      if (channel.nextProgram != null) merged.add(channel.nextProgram!);
    }
    final unique = <String, EpgProgram>{};
    for (final program in merged) {
      unique['${program.start.microsecondsSinceEpoch}:${program.title}'] =
          program;
    }
    final result = unique.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  static void _mergeGuide(Map<String, List<EpgProgram>> incoming) {
    for (final entry in incoming.entries) {
      final existing = _guide.putIfAbsent(entry.key, () => <EpgProgram>[]);
      final seen = existing
          .map((p) => '${p.start.microsecondsSinceEpoch}:${p.title}')
          .toSet();
      for (final program in entry.value) {
        final key = '${program.start.microsecondsSinceEpoch}:${program.title}';
        if (seen.add(key)) existing.add(program);
      }
      existing.sort((a, b) => a.start.compareTo(b.start));
    }
  }

  static Set<String> _wantedKeys(List<Channel> channels) {
    final keys = <String>{};
    for (final ch in channels) {
      for (final key in _keysForChannel(ch)) {
        if (key.isNotEmpty) keys.add(key);
      }
    }
    return keys;
  }

  static Iterable<String> _keysForChannel(Channel ch) sync* {
    if (ch.tvgId != null) yield _norm(ch.tvgId!);
    if (ch.tvgName != null) yield _norm(ch.tvgName!);
    yield _norm(ch.name);
    yield _norm(ch.displayName);
  }

  static List<String> _prioritizeUrls(
    List<String> urls,
    List<Channel> channels,
  ) {
    final countries = channels
        .map((c) => c.countryCode)
        .whereType<String>()
        .map((c) => c.toUpperCase())
        .toSet();

    int score(String url) {
      final upper = url.toUpperCase();
      if (upper.contains('ALL_SOURCES')) return 1;
      for (final code in countries) {
        if (upper.contains('_${code}1.XML') ||
            upper.contains('_${code}2.XML') ||
            upper.contains('_${code}3.XML') ||
            upper.contains('_${code}4.XML')) {
          return 100;
        }
      }
      return 10;
    }

    final copy = urls.toList();
    copy.sort((a, b) => score(b).compareTo(score(a)));
    return copy;
  }

  static bool _allMatched(List<Channel> channels) {
    final live = channels.where((c) => c.type == MediaType.live).toList();
    if (live.isEmpty) return true;
    final matched = live
        .where((c) => c.currentProgram != null || c.nextProgram != null)
        .length;
    return matched >= (live.length * 0.65);
  }

  static Future<String> _fetchXml(String url) async {
    final response = await http
        .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    List<int> bytes = response.bodyBytes;
    if (url.toLowerCase().endsWith('.gz')) {
      bytes = gzip.decode(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static Map<String, List<EpgProgram>> _parsePrograms(
    String xml,
    Set<String> wanted,
    DateTime now,
  ) {
    final out = <String, List<EpgProgram>>{};
    final programmeRegex = RegExp(
      r'<programme\b([^>]*)>([\s\S]*?)</programme>',
      caseSensitive: false,
    );

    for (final match in programmeRegex.allMatches(xml)) {
      final attrs = _attrs(match.group(1) ?? '');
      final channel = attrs['channel'];
      if (channel == null) continue;
      final channelKey = _norm(channel);
      if (!wanted.contains(channelKey)) continue;

      final start = _parseXmlTvTime(attrs['start']);
      final stop = _parseXmlTvTime(attrs['stop']);
      if (start == null || stop == null || !stop.isAfter(now)) continue;
      if (start.isAfter(now.add(const Duration(hours: 8)))) continue;

      final body = match.group(2) ?? '';
      final title = _tagText(body, 'title');
      if (title == null || title.trim().isEmpty) continue;

      final program = EpgProgram(
        channelId: channel,
        title: title.trim(),
        description: _tagText(body, 'desc')?.trim(),
        start: start,
        stop: stop,
      );
      out.putIfAbsent(channelKey, () => <EpgProgram>[]).add(program);
    }

    for (final list in out.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return out;
  }

  static void _attach(
    List<Channel> channels,
    Map<String, List<EpgProgram>> programs,
    DateTime now,
  ) {
    for (final ch in channels) {
      if (ch.type != MediaType.live) continue;
      if (ch.currentProgram != null && ch.nextProgram != null) continue;

      List<EpgProgram>? list;
      for (final key in _keysForChannel(ch)) {
        list = programs[key];
        if (list != null && list.isNotEmpty) break;
      }
      if (list == null || list.isEmpty) continue;

      ch.currentProgram ??= list
          .where((p) => p.isOnAt(now))
          .cast<EpgProgram?>()
          .firstWhere((p) => p != null, orElse: () => null);
      ch.nextProgram ??= list
          .where((p) => p.start.isAfter(now))
          .cast<EpgProgram?>()
          .firstWhere((p) => p != null, orElse: () => null);
    }
  }

  static Map<String, String> _attrs(String raw) {
    final attrs = <String, String>{};
    final attrRegex = RegExp(r'([\w:-]+)\s*=\s*["\x27]([^"\x27]*)["\x27]');
    for (final match in attrRegex.allMatches(raw)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) attrs[key] = _decodeXml(value);
    }
    return attrs;
  }

  static String? _tagText(String raw, String tag) {
    final regex = RegExp(
      '<$tag\\b[^>]*>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    );
    final match = regex.firstMatch(raw);
    if (match == null) return null;
    return _decodeXml(match.group(1) ?? '').replaceAll(RegExp(r'\s+'), ' ');
  }

  static DateTime? _parseXmlTvTime(String? raw) {
    if (raw == null || raw.length < 12) return null;
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?',
    ).firstMatch(raw.trim());
    if (match == null) return null;

    final y = int.parse(match.group(1)!);
    final mo = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final h = int.parse(match.group(4)!);
    final mi = int.parse(match.group(5)!);
    final s = int.parse(match.group(6) ?? '0');
    final offset = match.group(7);

    var dt = DateTime.utc(y, mo, d, h, mi, s);
    if (offset != null) {
      final sign = offset.startsWith('-') ? -1 : 1;
      final oh = int.parse(offset.substring(1, 3));
      final om = int.parse(offset.substring(3, 5));
      dt = dt.subtract(Duration(minutes: sign * ((oh * 60) + om)));
    }
    return dt;
  }

  static String _decodeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static String _norm(String value) {
    var out = value.toLowerCase().trim();
    final at = out.indexOf('@');
    if (at >= 0) out = out.substring(0, at);
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out;
  }
}
