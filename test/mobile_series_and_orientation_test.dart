import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/mobile_ui/hourtv_mobile_shell.dart';
import 'package:streamtv/models/channel.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';
import 'package:streamtv/services/xtream_service.dart';

void main() {
  test('el catálogo móvil incorpora las series estructuradas publicadas', () {
    final episode = Channel(
      name: 'Episodio 1',
      url: 'https://server.test/e/1',
      forcedType: 'series',
    );
    final structured = XtreamSeries(
      seriesId: 'catalog:serie-1',
      name: 'Serie publicada',
      host: '',
      username: '',
      password: '',
      episodes: [episode],
    );

    final content = hourTvMobileCatalogContent(const [], [structured]);

    expect(content, hasLength(1));
    expect(content.single.displayName, 'Serie publicada');
    expect(content.single.type, MediaType.series);
    expect(content.single.url, startsWith('hourtv-series:'));
  });

  test('el reproductor permite ambas orientaciones verticales por defecto', () {
    expect(hourTvPlayerOrientations(forceLandscape: false), [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    expect(hourTvPlayerOrientations(forceLandscape: true), [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  });
}
