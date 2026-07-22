import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/iptv_server_service.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  test('genera M3U para VOD, episodios y canales directos', () async {
    final store = ContentStore.instance;
    final previousChannels = store.all;
    final previousSeries = store.series;
    addTearDown(() {
      store.all = previousChannels;
      store.series = previousSeries;
    });

    store.all = [
      Channel(
        name: 'Película directa',
        url: 'https://cdn.example/pelicula.m3u8',
        forcedType: 'movie',
        categories: const ['anime'],
      ),
      Channel(
        name: 'Canal local',
        url: 'https://live.example/canal',
        group: 'Noticias',
      ),
    ];
    store.series = [
      XtreamSeries(
        seriesId: 'serie-1',
        name: 'Serie de prueba',
        host: '',
        username: '',
        password: '',
        episodes: [
          Channel(
            name: 'El episodio',
            url: 'https://cdn.example/serie-t2-e3.m3u8',
            group: 'T2',
            tvgId: 'catalog:serie-1:2:3',
            forcedType: 'series',
          ),
        ],
      ),
    ];

    final m3u = await IptvServerService.instance.buildPlaylist();

    expect(m3u, startsWith('#EXTM3U\n'));
    expect(m3u, contains('group-title="Anime",Película directa'));
    expect(m3u, contains('https://cdn.example/pelicula.m3u8'));
    expect(
      m3u,
      contains('group-title="Series",Serie de prueba · T2E3 El episodio'),
    );
    expect(m3u, contains('https://cdn.example/serie-t2-e3.m3u8'));
    expect(m3u, contains('group-title="Noticias",Canal local'));
    expect(m3u, contains('https://live.example/canal'));
  });
}
