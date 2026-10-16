import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/playback_source_fallback.dart';
import 'package:streamtv/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'orders preferred source, primary URL and mirrors without duplicates',
    () {
      final channel = Channel(
        name: 'Movie',
        url: 'https://primary.test/video.m3u8',
        servers: const [
          ChannelServer(
            name: 'Mirror A',
            url: 'https://mirror-a.test/video.m3u8',
          ),
          ChannelServer(
            name: 'Primary duplicate',
            url: 'https://primary.test/video.m3u8',
          ),
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
    },
  );

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

  test('starts with the server that previously worked for this series', () {
    final firstEpisode = Channel(
      name: 'Black Clover - Capítulo 1',
      url: 'https://tokianime.test/black-clover/1',
      forcedType: 'series',
      servers: const [
        ChannelServer(name: 'Servidor 1', url: 'https://one.test/e1'),
        ChannelServer(name: 'Servidor 7', url: 'https://seven.test/e1'),
      ],
    );
    final nextEpisode = Channel(
      name: 'Black Clover - Capítulo 2',
      url: 'https://tokianime.test/black-clover/2',
      forcedType: 'series',
      servers: const [
        ChannelServer(name: 'Servidor 1', url: 'https://one.test/e2'),
        ChannelServer(name: 'Servidor 7', url: 'https://seven.test/e2'),
      ],
    );

    expect(
      PlaybackServerPreference.contentKey(firstEpisode),
      PlaybackServerPreference.contentKey(nextEpisode),
    );
    final key = PlaybackServerPreference.serverKeyForUrl(
      firstEpisode,
      'https://seven.test/e1',
    );
    final plan = PlaybackSourcePlan.forChannel(
      nextEpisode,
      preferredServerKey: key,
    );

    expect(plan.current, 'https://seven.test/e2');
    expect(plan.currentIndex, 0);
  });

  test('prefers a stable server id when mirrors share a provider name', () {
    List<ChannelServer> mirrors(String episode) => [
      for (var index = 1; index <= 7; index++)
        ChannelServer(
          id: 'tokianime-server-$index',
          name: 'TokiAnime',
          url: 'https://tokianime.test/server-$index/$episode',
        ),
    ];

    final firstEpisodeServers = mirrors('episode-1');
    final firstEpisode = Channel(
      name: 'Asta y Yuno',
      url: firstEpisodeServers.first.url,
      tvgId: 'catalog:black-clover:1:1',
      tmdbId: 73223,
      forcedType: 'series',
      servers: firstEpisodeServers,
    );
    final nextEpisodeServers = mirrors('episode-2');
    final nextEpisode = Channel(
      name: 'El juramento del muchacho',
      url: nextEpisodeServers.first.url,
      tvgId: 'catalog:black-clover:1:2',
      tmdbId: 73223,
      forcedType: 'series',
      servers: nextEpisodeServers,
    );

    final key = PlaybackServerPreference.serverKeyForUrl(
      firstEpisode,
      firstEpisodeServers.last.url,
    );
    final plan = PlaybackSourcePlan.forChannel(
      nextEpisode,
      preferredServerKey: key,
    );

    expect(key, 'id:tokianime-server-7');
    expect(plan.current, nextEpisodeServers.last.url);
  });

  test('remembers the provider slot when mirror ids are missing', () {
    List<ChannelServer> mirrors(String episode, {bool promoteFirst = false}) =>
        [
          for (var index = 1; index <= 7; index++)
            ChannelServer(
              name: 'TokiAnime',
              url: 'https://tokianime.test/server-$index/$episode',
              health: promoteFirst && index == 1
                  ? const CatalogServerHealth(
                      status: 'active',
                      consecutiveFailures: 0,
                    )
                  : null,
            ),
        ];

    final firstEpisodeServers = mirrors('episode-1');
    final firstEpisode = Channel(
      name: 'Asta y Yuno',
      url: firstEpisodeServers.first.url,
      tvgId: 'catalog:black-clover:1:1',
      tmdbId: 73223,
      forcedType: 'series',
      servers: firstEpisodeServers,
    );
    final nextEpisodeServers = mirrors('episode-2', promoteFirst: true);
    final nextEpisode = Channel(
      name: 'El juramento del muchacho',
      url: nextEpisodeServers.first.url,
      tvgId: 'catalog:black-clover:1:2',
      tmdbId: 73223,
      forcedType: 'series',
      servers: nextEpisodeServers,
    );

    final key = PlaybackServerPreference.serverKeyForUrl(
      firstEpisode,
      firstEpisodeServers.last.url,
    );
    final plan = PlaybackSourcePlan.forChannel(
      nextEpisode,
      preferredServerKey: key,
    );

    expect(
      PlaybackServerPreference.contentKey(firstEpisode),
      PlaybackServerPreference.contentKey(nextEpisode),
    );
    expect(key, 'slot:tokianime:7');
    expect(plan.current, nextEpisodeServers.last.url);
  });

  test(
    'persists the successful slot and reuses it on the next episode',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();

      List<ChannelServer> mirrors(String episode) => [
        for (var index = 1; index <= 7; index++)
          ChannelServer(
            name: 'TokiAnime',
            url: 'https://tokianime.test/server-$index/$episode',
          ),
      ];
      final firstEpisodeServers = mirrors('episode-1');
      final firstEpisode = Channel(
        name: 'Asta y Yuno',
        url: firstEpisodeServers.first.url,
        tvgId: 'catalog:black-clover:1:1',
        tmdbId: 73223,
        forcedType: 'series',
        servers: firstEpisodeServers,
      );
      final nextEpisodeServers = mirrors('episode-2');
      final nextEpisode = Channel(
        name: 'El juramento del muchacho',
        url: nextEpisodeServers.first.url,
        tvgId: 'catalog:black-clover:1:2',
        tmdbId: 73223,
        forcedType: 'series',
        servers: nextEpisodeServers,
      );

      await PlaybackServerPreference.rememberSuccess(
        firstEpisode,
        firstEpisodeServers.last.url,
      );
      final plan = PlaybackSourcePlan.forChannel(
        nextEpisode,
        preferredServerKey: PlaybackServerPreference.preferredServerKey(
          nextEpisode,
        ),
      );

      expect(
        PlaybackServerPreference.preferredServerKey(nextEpisode),
        'slot:tokianime:7',
      );
      expect(plan.current, nextEpisodeServers.last.url);
    },
  );

  test('persists and reuses the last working mirror for a movie', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    Channel movie({required String primaryUrl, required String backupUrl}) =>
        Channel(
          name: 'Mujercitas',
          url: primaryUrl,
          tmdbId: 399055,
          forcedType: 'movie',
          servers: [
            ChannelServer(name: 'Principal', url: primaryUrl),
            ChannelServer(name: 'Respaldo', url: backupUrl),
          ],
        );

    final firstWatch = movie(
      primaryUrl: 'https://one.test/watch?token=old-primary',
      backupUrl: 'https://two.test/watch?token=old-backup',
    );
    final nextWatch = movie(
      primaryUrl: 'https://one.test/watch?token=new-primary',
      backupUrl: 'https://two.test/watch?token=new-backup',
    );

    expect(
      PlaybackServerPreference.contentKey(firstWatch),
      PlaybackServerPreference.contentKey(nextWatch),
    );
    await PlaybackServerPreference.rememberSuccess(
      firstWatch,
      firstWatch.servers.last.url,
    );

    final plan = PlaybackSourcePlan.forChannel(
      nextWatch,
      preferredServerKey: PlaybackServerPreference.preferredServerKey(
        nextWatch,
      ),
    );
    expect(
      PlaybackServerPreference.preferredServerKey(nextWatch),
      'name:respaldo',
    );
    expect(plan.current, nextWatch.servers.last.url);

    final stored = StorageService.getSetting(
      'lastWorkingPlaybackServerBySeries.v1',
    );
    expect(stored.toString(), isNot(contains('token=')));
  });

  test('separates same-title movies by release year when ids are missing', () {
    final older = Channel(
      name: 'It',
      url: 'https://provider.test/it-1990',
      year: '1990',
      forcedType: 'movie',
    );
    final newer = Channel(
      name: 'It',
      url: 'https://provider.test/it-2017',
      year: '2017',
      forcedType: 'movie',
    );

    expect(PlaybackServerPreference.contentKey(older), 'movie:title:it:1990');
    expect(
      PlaybackServerPreference.contentKey(older),
      isNot(PlaybackServerPreference.contentKey(newer)),
    );
  });

  test('does not treat a shared legacy provider name as a working mirror', () {
    final servers = [
      for (var index = 1; index <= 7; index++)
        ChannelServer(
          name: 'TokiAnime',
          url: 'https://tokianime.test/server-$index/episode-2',
        ),
    ];
    final channel = Channel(
      name: 'Black Clover - Capítulo 2',
      url: servers.first.url,
      forcedType: 'series',
      servers: servers,
    );

    final plan = PlaybackSourcePlan.forChannel(
      channel,
      preferredServerKey: 'name:tokianime',
    );

    expect(plan.current, servers.first.url);
  });

  test('puts recently active catalog mirrors ahead of unchecked sources', () {
    final channel = Channel(
      name: 'Show S01E01',
      url: 'https://primary.test/episode',
      forcedType: 'series',
      servers: const [
        ChannelServer(
          name: 'Offline',
          url: 'https://offline.test/episode',
          health: CatalogServerHealth(status: 'down', consecutiveFailures: 4),
        ),
        ChannelServer(
          name: 'Verified',
          url: 'https://verified.test/episode',
          health: CatalogServerHealth(status: 'active', consecutiveFailures: 0),
        ),
      ],
    );

    final plan = PlaybackSourcePlan.forChannel(channel);
    expect(plan.current, 'https://verified.test/episode');
    expect(plan.sources.last, 'https://offline.test/episode');
  });

  test('explicit server choice becomes the next automatic-fallback origin', () {
    final plan = PlaybackSourcePlan.forChannel(
      Channel(
        name: 'Channel',
        url: 'https://first.test/watch',
        servers: const [
          ChannelServer(name: 'Second', url: 'https://second.test/watch'),
        ],
      ),
    );

    expect(plan.select('https://second.test/watch'), isTrue);
    expect(plan.current, 'https://second.test/watch');
    expect(plan.advance(), isNull);
  });
}
