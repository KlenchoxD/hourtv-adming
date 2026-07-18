import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/services/content_store.dart';
import 'package:streamtv/services/iptv_server_service.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  test('genera M3U para VOD, episodios, canales y embeds diferidos', () {
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
        name: 'Película embed',
        url: 'https://embed.example/watch/42',
        forcedType: 'movie',
        categories: const ['infantil'],
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
            url: 'https://embed.example/episode/3',
            group: 'T2',
            tvgId: 'catalog:serie-1:2:3',
            forcedType: 'series',
          ),
        ],
      ),
    ];

    final m3u = IptvServerService.instance.buildPlaylist(
      'http://192.168.1.7:8090',
    );

    expect(m3u, startsWith('#EXTM3U\n'));
    expect(m3u, contains('group-title="Anime",Película directa'));
    expect(m3u, contains('https://cdn.example/pelicula.m3u8'));
    expect(m3u, contains('group-title="Infantil",Película embed'));
    expect(
      m3u,
      contains(
        'http://192.168.1.7:8090/resolve?u=https%3A%2F%2Fembed.example%2Fwatch%2F42',
      ),
    );
    expect(
      m3u,
      contains('group-title="Series",Serie de prueba · T2E3 El episodio'),
    );
    expect(m3u, contains('group-title="Noticias",Canal local'));
    expect(m3u, contains('https://live.example/canal'));
  });
}
