import '../models/channel.dart';
import 'storage_service.dart';

/// Orden de intento de reproduccion para un canal: primero la fuente
/// preferida (si se paso una), luego la URL principal, luego cada servidor
/// alternativo, sin duplicados ni URLs vacias. Permite reintentar mirrors
/// cuando el stream falla en caliente (no solo cuando falla al resolver).
class PlaybackSourcePlan {
  PlaybackSourcePlan._(this._sources) : _index = 0;

  final List<String> _sources;
  int _index;

  /// Ordered, deduplicated candidate URLs used by playback and its handoff UI.
  List<String> get sources => _sources;

  /// Index of [current] in [sources], updated whenever [advance] succeeds.
  int get currentIndex => _index;

  factory PlaybackSourcePlan.forChannel(
    Channel channel, {
    String? preferredUrl,
    String? preferredServerKey,
  }) {
    final seen = <String>{};
    final sources = <String>[];
    void add(String? url) {
      final trimmed = url?.trim() ?? '';
      if (trimmed.isEmpty) return;
      if (seen.add(trimmed)) sources.add(trimmed);
    }

    final sourceServers = List<ChannelServer>.of(channel.servers);
    final servers = List<ChannelServer>.of(sourceServers)
      ..sort((a, b) {
        final rank = _healthRank(a).compareTo(_healthRank(b));
        if (rank != 0) return rank;
        final aSuccess = DateTime.tryParse(a.health?.lastSuccessAt ?? '');
        final bSuccess = DateTime.tryParse(b.health?.lastSuccessAt ?? '');
        if (aSuccess != null && bSuccess != null) {
          return bSuccess.compareTo(aSuccess);
        }
        return 0;
      });

    // Reuse an exact provider that has already played this series. Health
    // reported as down overrides a stale local success; otherwise the
    // learned server is tried before the episode's default source.
    if (preferredServerKey != null) {
      for (final server in servers) {
        if (_matchesServerKey(
              server,
              preferredServerKey,
              servers: servers,
              sourceOrder: sourceServers,
            ) &&
            server.effectiveHealthStatus != 'down') {
          add(server.url);
        }
      }
    }

    // A catalog health check is not proof of playback, but a recent active
    // server is a better cold-start candidate than an unchecked/dead mirror.
    for (final server in servers.where(
      (s) =>
          s.effectiveHealthStatus == 'active' ||
          s.effectiveHealthStatus == 'recovered',
    )) {
      add(server.url);
    }

    add(preferredUrl);
    add(channel.url);

    for (final server in servers.where(
      (s) => s.effectiveHealthStatus == 'pending',
    )) {
      add(server.url);
    }
    for (final server in servers.where(
      (s) => s.effectiveHealthStatus == 'degraded',
    )) {
      add(server.url);
    }
    for (final server in servers.where(
      (s) => s.effectiveHealthStatus == 'down',
    )) {
      add(server.url);
    }
    // Unknown health remains usable; it is merely lower priority than a
    // recently verified server.
    for (final server in servers.where(
      (s) => !{
        'active',
        'recovered',
        'pending',
        'degraded',
        'down',
      }.contains(s.effectiveHealthStatus),
    )) {
      add(server.url);
    }
    return PlaybackSourcePlan._(List.unmodifiable(sources));
  }

  String get current => _sources[_index];
  bool get hasNext => _index + 1 < _sources.length;

  /// Selects a server explicitly chosen by the viewer, keeping automatic
  /// fallback aligned with the selected item in the server wheel.
  bool select(String url) {
    final index = _sources.indexOf(url.trim());
    if (index < 0) return false;
    _index = index;
    return true;
  }

  /// Avanza a la siguiente fuente y la devuelve, o null si no quedan mas.
  String? advance() {
    if (!hasNext) return null;
    _index++;
    return _sources[_index];
  }

  static int _healthRank(ChannelServer server) =>
      switch (server.effectiveHealthStatus) {
        'active' || 'recovered' => 0,
        'pending' => 1,
        'degraded' => 2,
        'down' => 3,
        _ => 4,
      };

  static bool _matchesServerKey(
    ChannelServer server,
    String key, {
    required List<ChannelServer> servers,
    required List<ChannelServer> sourceOrder,
  }) {
    if (key.startsWith('id:')) {
      final id = PlaybackServerPreference.normalize(server.id ?? '');
      return id.isNotEmpty && id == key.substring('id:'.length);
    }

    if (key.startsWith('name:')) {
      final name = key.substring('name:'.length);
      final matches = servers
          .where(
            (candidate) =>
                PlaybackServerPreference.normalize(candidate.name) == name,
          )
          .length;
      return matches == 1 &&
          PlaybackServerPreference.normalize(server.name) == name;
    }

    if (key.startsWith('host:')) {
      final host = key.substring('host:'.length);
      final matches = servers
          .where((candidate) => _host(candidate.url) == host)
          .length;
      return matches == 1 && _host(server.url) == host;
    }

    if (key.startsWith('slot:')) {
      final match = RegExp(r'^slot:(.*):(\d+)$').firstMatch(key);
      if (match == null) return false;
      final provider = match.group(1)!;
      final index = int.parse(match.group(2)!) - 1;
      return index >= 0 &&
          index < sourceOrder.length &&
          identical(sourceOrder[index], server) &&
          PlaybackServerPreference.normalize(server.name) == provider;
    }
    return false;
  }

  static String? _host(String url) => Uri.tryParse(url)?.host.toLowerCase();
}

/// Per-title memory of the last server that actually played. Series episodes
/// share one preference; films get their own title key. Stable server ids are
/// preferred; sources without ids use a provider + list-position key. Signed
/// playback URLs and credentials are never persisted.
class PlaybackServerPreference {
  PlaybackServerPreference._();

  // Keep the v1 key so existing series preferences survive this expansion to
  // movies. The value remains a bounded map of content keys to server keys.
  static const _storageKey = 'lastWorkingPlaybackServerBySeries.v1';
  static const _maxEntries = 100;
  static const _maxAge = Duration(days: 30);

  static String? contentKey(Channel channel) {
    if (channel.type == MediaType.series) {
      final tmdbId = channel.tmdbId;
      final title = normalizeSeriesTitle(channel.seriesTitle);
      if (tmdbId == null && title.isEmpty) return null;
      return tmdbId == null ? 'series:title:$title' : 'series:tmdb:$tmdbId';
    }
    if (channel.type != MediaType.movie) return null;

    final catalogId = channel.catalogTitleId?.trim();
    if (catalogId != null && catalogId.isNotEmpty) {
      return 'movie:catalog:${normalize(catalogId)}';
    }
    if (channel.url.startsWith('catalog://')) {
      final id = channel.url.substring('catalog://'.length).trim();
      if (id.isNotEmpty) return 'movie:catalog:${normalize(id)}';
    }
    final tmdbId = channel.tmdbId;
    if (tmdbId != null) return 'movie:tmdb:$tmdbId';

    final tvgId = channel.tvgId?.trim();
    if (tvgId != null && tvgId.isNotEmpty) {
      return 'movie:tvg:${normalize(tvgId)}';
    }

    final title = normalize(channel.displayName);
    if (title.isEmpty) return null;
    final year = normalize(channel.year ?? '');
    return year.isEmpty ? 'movie:title:$title' : 'movie:title:$title:$year';
  }

  static String normalizeSeriesTitle(String value) {
    final title = value
        .replaceAll(
          RegExp(
            r'\s*(?:cap[ií]tulo|episodio|episode|ep\.?|chapter)\s*#?\s*\d+.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*(?:temporada|season)\s*#?\s*\d+.*$',
            caseSensitive: false,
          ),
          '',
        );
    return normalize(title);
  }

  static String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String? serverKeyForUrl(Channel channel, String url) {
    final normalizedUrl = url.trim();
    final matchingServers = channel.servers
        .where((server) => server.url.trim() == normalizedUrl)
        .toList(growable: false);
    if (matchingServers.length == 1) {
      final server = matchingServers.single;
      final id = normalize(server.id ?? '');
      if (id.isNotEmpty &&
          channel.servers
                  .where((candidate) => normalize(candidate.id ?? '') == id)
                  .length ==
              1) {
        return 'id:$id';
      }

      final name = normalize(server.name);
      if (name.isNotEmpty &&
          channel.servers
                  .where((candidate) => normalize(candidate.name) == name)
                  .length ==
              1) {
        return 'name:$name';
      }

      final host = Uri.tryParse(normalizedUrl)?.host.toLowerCase();
      if (host != null &&
          host.isNotEmpty &&
          channel.servers
                  .where(
                    (candidate) =>
                        Uri.tryParse(candidate.url)?.host.toLowerCase() == host,
                  )
                  .length ==
              1) {
        return 'host:$host';
      }

      final index = channel.servers.indexOf(server);
      if (index >= 0) {
        return 'slot:$name:${index + 1}';
      }
    }

    // A source not present exactly once in the episode list cannot be mapped
    // safely to the same provider in the next episode.
    return null;
  }

  static String? preferredServerKey(Channel channel) {
    final key = contentKey(channel);
    if (key == null) return null;
    final raw = StorageService.getSetting(_storageKey);
    if (raw is! Map) return null;
    final entry = raw[key];
    if (entry is! Map) return null;
    final serverKey = entry['serverKey']?.toString();
    final updatedAt = int.tryParse('${entry['updatedAt'] ?? ''}');
    if (serverKey == null || serverKey.isEmpty || updatedAt == null) {
      return null;
    }
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
    return age.isNegative || age > _maxAge ? null : serverKey;
  }

  static Future<void> rememberSuccess(Channel channel, String url) async {
    final content = contentKey(channel);
    final serverKey = serverKeyForUrl(channel, url);
    if (content == null || serverKey == null) return;

    final raw = StorageService.getSetting(_storageKey);
    final entries = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    entries.remove(content);
    entries[content] = {
      'serverKey': serverKey,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    while (entries.length > _maxEntries) {
      entries.remove(entries.keys.first);
    }
    await StorageService.saveSetting(_storageKey, entries);
  }
}
