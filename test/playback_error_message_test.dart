import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/new_ui/hourtv_player_screen.dart';

void main() {
  test('traduce los fallos tipicos de una fuente IPTV', () {
    expect(
      playbackErrorMessage(
        'PlatformException(VideoError, Source error: Response code: 403)',
      ),
      contains('rechazó la conexión'),
    );
    expect(
      playbackErrorMessage('HttpDataSourceException: Response code: 404'),
      contains('ya no existe'),
    );
    expect(
      playbackErrorMessage('SocketException: Failed host lookup: cdn.test'),
      contains('conexión a internet'),
    );
    expect(
      playbackErrorMessage('TimeoutException after 0:00:30.000000'),
      contains('tardó demasiado'),
    );
    expect(
      playbackErrorMessage('Response code: 502'),
      contains('está fallando'),
    );
    expect(
      playbackErrorMessage(
        'UnrecognizedInputFormatException: None of the available extractors',
      ),
      contains('formato de video'),
    );
    expect(
      playbackErrorMessage('CLEARTEXT communication to cdn.test not permitted'),
      contains('HTTP sin cifrar'),
    );
  });

  test('nunca devuelve el texto crudo de la excepcion', () {
    const raw = 'PlatformException(VideoError, ExoPlaybackException, null)';
    final message = playbackErrorMessage(raw);
    expect(message, isNot(contains('PlatformException')));
    expect(message, isNot(contains('ExoPlaybackException')));
    expect(message, isNotEmpty);
  });

  test('sin detalle sigue diciendo algo util', () {
    expect(playbackErrorMessage(null), isNotEmpty);
    expect(playbackErrorMessage(''), isNotEmpty);
  });
}
