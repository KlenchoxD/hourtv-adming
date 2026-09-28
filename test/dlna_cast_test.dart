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
}
