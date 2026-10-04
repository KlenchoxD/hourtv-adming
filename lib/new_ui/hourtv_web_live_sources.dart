import '../models/channel.dart';
import 'hourtv_web_live_policy.dart';

/// Targeted replacements only: preserve channel identity, favourites and EPG.
/// Provider credentials and upstream URLs exist exclusively in Worker secrets.
String hourTvWebLivePlaybackUrl(Channel channel) {
  const root = 'https://hourtv-live-relay.hourtv-release-20261002.workers.dev';
  if (channel.type != MediaType.live) return channel.url;
  final audited = HourTvWebLivePolicy.instance.playbackReplacement(channel);
  if (audited != null) return audited;
  final name = channel.displayName.toLowerCase().trim();
  const replacements = {
    'canal rcn': 'rcn',
    'rcn mas': 'rcn-mas',
    'rcn más': 'rcn-mas',
    'rcn hd2': 'rcn-hd2',
  };
  final id = replacements[name];
  return id == null ? channel.url : '$root/live/$id.m3u8';
}
