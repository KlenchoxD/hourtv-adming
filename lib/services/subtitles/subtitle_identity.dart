import '../../models/channel.dart';
import '../xtream_service.dart';

typedef SubtitleIdentity = ({
  String title,
  int? season,
  int? episode,
  String? tmdbId,
  String? imdbId,
});

/// Identidad del contenido, nunca el texto genérico «Episodio 1» de la tarjeta.
SubtitleIdentity subtitleIdentity(
  Channel channel,
  Iterable<XtreamSeries> series,
) {
  XtreamSeries? parent;
  final id = channel.tvgId ?? '';
  for (final item in series) {
    if (id.startsWith('${item.seriesId}:') ||
        (item.episodes ?? const <Channel>[]).any(
          (ep) =>
              (id.startsWith('catalog:') && ep.tvgId == id) ||
              (channel.url.isNotEmpty && ep.url == channel.url),
        )) {
      parent = item;
      break;
    }
  }
  final pair =
      RegExp(r'(?:^|:)S(\d+):E(\d+)$', caseSensitive: false).firstMatch(id) ??
      RegExp(r':(\d+):(\d+)$').firstMatch(id) ??
      RegExp(r'S(\d+)\s*E(\d+)', caseSensitive: false).firstMatch(channel.name);
  final season = pair != null
      ? int.tryParse(pair.group(1)!)
      : int.tryParse(
          RegExp(
                r'(?:T|Temporada)\s*(\d+)',
                caseSensitive: false,
              ).firstMatch(channel.group ?? '')?.group(1) ??
              '',
        );
  final episode = pair != null
      ? int.tryParse(pair.group(2)!)
      : int.tryParse(
          RegExp(
                r'(?:Episodio|Cap[ií]tulo)\s*(\d+)',
                caseSensitive: false,
              ).firstMatch(channel.name)?.group(1) ??
              '',
        );
  final tmdb =
      channel.tmdbId ??
      parent?.episodes?.where((e) => e.tmdbId != null).firstOrNull?.tmdbId;
  final legacyTmdb = RegExp(
    r'^tmdb[:/](\d+)$',
    caseSensitive: false,
  ).firstMatch(id)?.group(1);
  return (
    title: parent?.name ?? channel.displayName,
    season: season,
    episode: episode,
    tmdbId: tmdb?.toString() ?? legacyTmdb,
    imdbId: RegExp(r'^tt\d+$').hasMatch(id) ? id : null,
  );
}
