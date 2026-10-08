import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_components.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/storage_service.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  final store = ContentStore.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    store.resetForTesting();
  });
  tearDown(store.resetForTesting);

  Future<Channel> episode({
    String? cover = 'https://img.invalid/series.jpg',
  }) async {
    final item = Channel(
      name: 'Ryomen Sukuna',
      url: 'https://video.invalid/episode1.mp4',
      logo: 'https://img.invalid/episode-still.jpg',
      tvgId: 'catalog:jjk:1:1',
      forcedType: 'series',
      duration: '24',
    );
    store.all = [item];
    store.series = [
      XtreamSeries(
        seriesId: 'catalog:jjk',
        name: 'Jujutsu Kaisen',
        cover: cover,
        host: '',
        username: '',
        password: '',
        episodes: [item],
      ),
    ];
    await StorageService.saveRecent(item);
    await store.updatePlaybackProgress(item, .4);
    return item;
  }

  test(
    'resume tile uses series cover but keeps the original episode',
    () async {
      final item = await episode();
      final entry = store.continueWatchingEntries.single;
      expect(entry.posterUrl, 'https://img.invalid/series.jpg');
      expect(entry.channel, same(item));
      expect(entry.channel.progressFraction, .4);
      expect(entry.channel.url, 'https://video.invalid/episode1.mp4');
      expect(store.continueWatching.single, same(item));
      expect(item.logo, 'https://img.invalid/episode-still.jpg');
      expect(store.series.single.episodes!.single.logo, item.logo);
      expect(StorageService.loadRecent().single.logo, item.logo);
    },
  );

  test('missing series cover keeps the available episode artwork', () async {
    final item = await episode(cover: '  ');
    expect(store.continueWatchingEntries.single.posterUrl, item.logo);
  });

  test(
    'unavailable parent does not hide the saved episode or progress',
    () async {
      final item = await episode();
      store.series = [];
      final entry = store.continueWatchingEntries.single;
      expect(entry.channel, same(item));
      expect(entry.posterUrl, item.logo);
      expect(entry.channel.progressFraction, .4);
    },
  );

  test('movies retain their own poster and playback identity', () async {
    final movie = Channel(
      name: 'Película',
      url: 'vod:movie',
      forcedType: 'movie',
      logo: 'https://img.invalid/movie.jpg',
    );
    store.all = [movie];
    await StorageService.saveRecent(movie);
    await store.updatePlaybackProgress(movie, .5);
    final entry = store.continueWatchingEntries.single;
    expect(entry.posterUrl, movie.logo);
    expect(entry.channel, same(movie));
  });

  testWidgets('Home paints the series cover and resumes the original episode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = await episode();
    final movie = Channel(
      name: 'Película de catálogo',
      url: 'vod:catalog',
      forcedType: 'movie',
    );
    store.all = [item, movie];
    Channel? resumed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HourTvMobileHome(
            store: store,
            allContent: [item, movie],
            movies: [movie],
            onOpen: (_) {},
            onOpenContinue: (channel) => resumed = channel,
            onProfile: () {},
            onSearch: () {},
          ),
        ),
      ),
    );
    // This assertion is about the selected artwork URL, not a network load.
    // Native HTTP is deliberately unavailable in a widget-test process.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final finder = find.byKey(ValueKey('continue-${item.url}'));
    final tile = tester.widget<HourTvPosterCard>(finder);
    expect(tile.artworkUrl, store.series.single.cover);
    expect(tile.channel, same(item));
    await tester.tap(finder);
    await tester.pump();
    expect(resumed, same(item));
    expect(item.logo, 'https://img.invalid/episode-still.jpg');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('shared artwork widget always uses proportional decode bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 160,
          height: 90,
          child: HourTvArtwork(
            asset: 'assets/figma/phase-3-1/hero-el-ultimo-amanecer.png',
            memCacheWidth: 160,
            memCacheHeight: 90,
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.policy, ResizeImagePolicy.fit);
    expect(provider.width, 160);
    expect(provider.height, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native poster titles are larger and visually stronger', (
    tester,
  ) async {
    final item = Channel(
      name: 'Título de película',
      url: 'vod:movie',
      forcedType: 'movie',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HourTvPosterCard(channel: item, onTap: () {}),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Título de película'));
    expect(title.style!.fontSize, 14);
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search and profile have visible 48px targets without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var searches = 0;
    var profiles = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HourTvMobileHeader(
            onAvatarTap: () => profiles++,
            trailing: HourTvHeaderSearchButton(onPressed: () => searches++),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byTooltip('Buscar')), const Size(48, 48));
    expect(tester.getSize(find.byTooltip('Perfil')), const Size(48, 48));
    final search = tester.widget<Icon>(find.byIcon(Icons.search_rounded));
    expect(search.size, 28);
    await tester.tap(find.byTooltip('Buscar'));
    await tester.tap(find.byTooltip('Perfil'));
    expect(searches, 1);
    expect(profiles, 1);
    expect(tester.takeException(), isNull);
  });
}
