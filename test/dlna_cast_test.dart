import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/cast_proxy.dart';
import 'package:streamtv/services/dlna_service.dart';

void main() {
  test('lee nombre y URLs de control de la descripción de un TV', () {
    const xml = '''<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>[TV] Samsung Sala &amp; Comedor</friendlyName>
    <modelName>UN55TU8000</modelName>
    <UDN>uuid:1234</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/upnp/control/RenderingControl1</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/upnp/control/AVTransport1</controlURL>
      </service>
    </serviceList>
  </device>
</root>''';
    final tv = DlnaRenderer.fromDescription(
      xml,
      Uri.parse('http://192.168.1.20:9197/dmr'),
    )!;
    expect(tv.name, '[TV] Samsung Sala & Comedor');
    expect(tv.model, 'UN55TU8000');
    expect(tv.id, 'uuid:1234');
    expect(
      tv.avTransportUrl.toString(),
      'http://192.168.1.20:9197/upnp/control/AVTransport1',
    );
    expect(
      tv.renderingControlUrl.toString(),
      'http://192.168.1.20:9197/upnp/control/RenderingControl1',
    );
  });

  test('un dispositivo sin AVTransport no es un TV', () {
    const xml =
        '<root><device><friendlyName>Router</friendlyName>'
        '<serviceList><service><serviceType>urn:schemas-upnp-org:service:'
        'WANIPConnection:1</serviceType><controlURL>/c</controlURL></service>'
        '</serviceList></device></root>';
    expect(
      DlnaRenderer.fromDescription(xml, Uri.parse('http://192.168.1.1/')),
      isNull,
    );
  });

  test('tiempos UPnP', () {
    expect(
      DlnaService.parseTime('01:02:03.500'),
      const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500),
    );
    expect(DlnaService.parseTime('NOT_IMPLEMENTED'), Duration.zero);
    expect(
      DlnaService.formatTime(const Duration(minutes: 75, seconds: 7)),
      '01:15:07',
    );
  });

  test('el proxy reescribe segmentos, variantes y claves de una lista HLS', () {
    const playlist = '''#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",URI="https://cdn2.test/audio.m3u8"
#EXTINF:6.0,
seg0.ts

#EXTINF:6.0,
/abs/seg1.ts''';
    final out = CastProxy.rewritePlaylist(
      playlist,
      Uri.parse('https://cdn.test/hls/index.m3u8?token=x'),
      (uri) => 'P<$uri>',
    );
    expect(out.split('\n'), [
      '#EXTM3U',
      '#EXT-X-KEY:METHOD=AES-128,URI="P<https://cdn.test/hls/key.bin>"',
      '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",URI="P<https://cdn2.test/audio.m3u8>"',
      '#EXTINF:6.0,',
      'P<https://cdn.test/hls/seg0.ts>',
      '',
      '#EXTINF:6.0,',
      'P<https://cdn.test/abs/seg1.ts>',
    ]);
  });

  test('el subtítulo se convierte a WebVTT para Chromecast y a SRT para DLNA', () {
    const srt = '\uFEFF1\r\n00:00:01,500 --> 00:00:04,000\r\nHola\r\n';
    expect(
      CastProxy.toVtt(srt),
      'WEBVTT\n\n1\n00:00:01.500 --> 00:00:04.000\nHola\n',
    );
    expect(CastProxy.toSrt(srt), '1\n00:00:01,500 --> 00:00:04,000\nHola\n');
    const vtt = 'WEBVTT\n\n00:00:01.500 --> 00:00:04.000\nHola\n';
    expect(CastProxy.toVtt(vtt), vtt);
    expect(CastProxy.toSrt(vtt), '00:00:01,500 --> 00:00:04,000\nHola\n');
  });

  test('la lista maestra HLS declara la pista de subtítulos para Chromecast', () {
    const master =
        '#EXTM3U\n'
        '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="s",URI="http://x/sub.m3u8"\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=800000,SUBTITLES="s"\n'
        'P<720>\n';
    final out = CastProxy.withSubtitles(master, 'http://tv/sub.m3u8', 'P<m>');
    expect(out.split('\n'), [
      '#EXTM3U',
      '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="hourtv-subs",NAME="Español",'
          'LANGUAGE="es",DEFAULT=NO,AUTOSELECT=NO,FORCED=NO,'
          'URI="http://tv/sub.m3u8"',
      '#EXT-X-STREAM-INF:BANDWIDTH=800000,SUBTITLES="hourtv-subs"',
      'P<720>',
      '',
    ]);

    // Lista de segmentos (sin variantes): se envuelve en una maestra.
    final wrapped = CastProxy.withSubtitles(
      '#EXTM3U\n#EXTINF:6,\nP<seg>\n',
      'http://tv/sub.m3u8',
      'P<media>',
    );
    expect(wrapped, contains('SUBTITLES="hourtv-subs"\nP<media>'));
    expect(
      CastProxy.lastCueEnd('WEBVTT\n\n00:00:01.000 --> 01:02:03.500\nx\n'),
      const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500),
    );
  });

  test('WebVTT de la pista HLS: sin números y con X-TIMESTAMP-MAP', () {
    const vtt = 'WEBVTT\n\n1\n00:00:01.000 --> 00:00:02.000\nHola\n\n'
        '2\n00:00:03.000 --> 00:00:04.000\n12 perros\n';
    expect(
      CastProxy.hlsVtt(vtt, 126000),
      'WEBVTT\nX-TIMESTAMP-MAP=MPEGTS:126000,LOCAL:00:00:00.000\n\n'
      '00:00:01.000 --> 00:00:02.000\nHola\n\n'
      '00:00:03.000 --> 00:00:04.000\n12 perros\n',
    );
  });

  test('lee el primer PTS de un segmento MPEG-TS', () {
    // PTS = 126000 (1,4 s): 0x21 0x00 0x07 0xD8 0x61 en la cabecera PES.
    final packet = List<int>.filled(188, 0xFF);
    packet.setAll(0, [0x47, 0x41, 0x00, 0x10]);
    packet.setAll(4, [0, 0, 1, 0xE0, 0, 0, 0x80, 0x80, 5]);
    packet.setAll(13, [0x21, 0x00, 0x07, 0xD8, 0x61]);
    expect(CastProxy.firstPts(packet), 126000);
    expect(CastProxy.firstPts(List<int>.filled(188, 0)), isNull);
  });
}
