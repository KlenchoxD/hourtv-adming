import '../models/channel.dart';

/// Orden de intento de reproduccion para un canal: primero la fuente
/// preferida (si se paso una), luego la URL principal, luego cada servidor
/// alternativo, sin duplicados ni URLs vacias. Permite reintentar mirrors
/// cuando el stream falla en caliente (no solo cuando falla al resolver).
class PlaybackSourcePlan {
  PlaybackSourcePlan._(this._sources) : _index = 0;

  final List<String> _sources;
  int _index;

  factory PlaybackSourcePlan.forChannel(
    Channel channel, {
    String? preferredUrl,
  }) {
    final seen = <String>{};
    final sources = <String>[];
    void add(String? url) {
      final trimmed = url?.trim() ?? '';
      if (trimmed.isEmpty) return;
      if (seen.add(trimmed)) sources.add(trimmed);
    }

    add(preferredUrl);
    add(channel.url);
    for (final server in channel.servers) {
      add(server.url);
    }
    return PlaybackSourcePlan._(List.unmodifiable(sources));
  }

  String get current => _sources[_index];
  bool get hasNext => _index + 1 < _sources.length;

  /// Avanza a la siguiente fuente y la devuelve, o null si no quedan mas.
  String? advance() {
    if (!hasNext) return null;
    _index++;
    return _sources[_index];
  }
}
