import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const _avTransport = 'urn:schemas-upnp-org:service:AVTransport:1';
const _renderingControl = 'urn:schemas-upnp-org:service:RenderingControl:1';

/// Un TV o receptor DLNA/UPnP (Smart TV Samsung, LG, Sony, TCL, Android TV
/// con receptor DLNA...). Es lo que usan Xuper y la mayoría de apps IPTV.
class DlnaRenderer {
  const DlnaRenderer({
    required this.id,
    required this.name,
    required this.avTransportUrl,
    this.renderingControlUrl,
    this.model,
  });

  final String id;
  final String name;
  final String? model;
  final Uri avTransportUrl;
  final Uri? renderingControlUrl;

  /// Lee la descripción del dispositivo (XML de UPnP). Null si no es un
  /// reproductor (no tiene AVTransport).
  @visibleForTesting
  static DlnaRenderer? fromDescription(String xml, Uri location) {
    String? tag(String source, String name) {
      final m = RegExp(
        '<(?:\\w+:)?$name>([\\s\\S]*?)</(?:\\w+:)?$name>',
      ).firstMatch(source);
      final value = m?.group(1)?.trim();
      return value == null || value.isEmpty ? null : _unescape(value);
    }

    final urlBase = tag(xml, 'URLBase');
    final base = urlBase == null ? location : location.resolve(urlBase);
    Uri? control(String type) {
      for (final m in RegExp(
        r'<(?:\w+:)?service>([\s\S]*?)</(?:\w+:)?service>',
      ).allMatches(xml)) {
        final block = m.group(1)!;
        if (tag(block, 'serviceType') != type) continue;
        final url = tag(block, 'controlURL');
        if (url != null) return base.resolve(url);
      }
      return null;
    }

    final av = control(_avTransport);
    if (av == null) return null;
    return DlnaRenderer(
      id: tag(xml, 'UDN') ?? location.toString(),
      name: tag(xml, 'friendlyName') ?? location.host,
      model: tag(xml, 'modelName'),
      avTransportUrl: av,
      renderingControlUrl: control(_renderingControl),
    );
  }
}

/// Estado del reproductor del TV.
typedef DlnaStatus = ({String state, Duration position, Duration duration});

class DlnaException implements Exception {
  const DlnaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DlnaService {
  DlnaService._();

  static final DlnaService instance = DlnaService._();
  static const _device = MethodChannel('hourtv/device');

  /// TVs encontrados en la última búsqueda.
  final renderers = ValueNotifier<List<DlnaRenderer>>(const []);
  final searching = ValueNotifier<bool>(false);

  Future<void>? _scan;

  /// Busca TVs en la red Wi-Fi (SSDP, como cualquier control DLNA). Cada
  /// respuesta se agrega a [renderers] en cuanto llega.
  Future<void> scan({Duration timeout = const Duration(seconds: 6)}) =>
      _scan ??= _doScan(timeout).whenComplete(() => _scan = null);

  Future<void> _doScan(Duration timeout) async {
    // Solo en el teléfono Android; nunca desde las pruebas automáticas (no
    // deben enviar paquetes a la red de quien las corre).
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    // TVs apagados desde la última búsqueda no deben seguir en la lista.
    renderers.value = const [];
    searching.value = true;
    RawDatagramSocket? socket;
    final seen = <String>{};
    final pending = <Future<void>>[];
    try {
      await _multicastLock(true);
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.multicastHops = 4;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final packet = socket?.receive();
        if (packet == null) return;
        final location = _header(
          latin1.decode(packet.data, allowInvalid: true),
          'location',
        );
        final uri = location == null ? null : Uri.tryParse(location);
        if (uri == null || !seen.add(uri.toString())) return;
        pending.add(_describe(uri));
      });

      final group = InternetAddress('239.255.255.250');
      // Se repite: UDP puede perder paquetes y algunos TV responden tarde.
      for (var i = 0; i < 3; i++) {
        for (final st in const [
          'urn:schemas-upnp-org:device:MediaRenderer:1',
          _avTransport,
        ]) {
          socket.send(utf8.encode(_search(st)), group, 1900);
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      await Future<void>.delayed(timeout - const Duration(milliseconds: 2400));
      await Future.wait(pending);
      debugPrint(
        '[DLNA] respondieron ${seen.length}, TVs ${renderers.value.length}',
      );
    } catch (e) {
      debugPrint('[DLNA] scan ${e.runtimeType}');
    } finally {
      socket?.close();
      await _multicastLock(false);
      searching.value = false;
    }
  }

  static String _search(String st) =>
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: $st\r\n'
      'USER-AGENT: Android UPnP/1.1 HourTV/1.0\r\n\r\n';

  static String? _header(String message, String name) {
    for (final line in const LineSplitter().convert(message)) {
      final colon = line.indexOf(':');
      if (colon > 0 && line.substring(0, colon).trim().toLowerCase() == name) {
        return line.substring(colon + 1).trim();
      }
    }
    return null;
  }

  Future<void> _describe(Uri location) async {
    try {
      final res = await http.get(location).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return;
      final renderer = DlnaRenderer.fromDescription(
        utf8.decode(res.bodyBytes, allowMalformed: true),
        location,
      );
      if (renderer == null) return;
      final list = [...renderers.value]
        ..removeWhere((r) => r.id == renderer.id)
        ..add(renderer);
      renderers.value = List.unmodifiable(list);
    } catch (_) {
      // Dispositivo que no responde: se ignora.
    }
  }

  Future<void> _multicastLock(bool acquire) async {
    try {
      await _device.invokeMethod<void>('multicastLock', {'acquire': acquire});
    } catch (_) {
      // Sin canal nativo (pruebas, escritorio): no hace falta.
    }
  }

  // --- Control del reproductor del TV (UPnP AVTransport) ---

  Future<void> load(
    DlnaRenderer tv, {
    required String url,
    required String title,
    required String mimeType,
    Duration position = Duration.zero,
  }) async {
    // Algunos TV rechazan un video nuevo mientras reproducen otro.
    await _tryAv(tv, 'Stop', '');
    final didl =
        '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="0" parentID="-1" restricted="1">'
        '<dc:title>${_escape(title)}</dc:title>'
        '<upnp:class>object.item.videoItem.movie</upnp:class>'
        '<res protocolInfo="http-get:*:$mimeType:DLNA.ORG_OP=01;DLNA.ORG_CI=0;'
        'DLNA.ORG_FLAGS=01700000000000000000000000000000">'
        '${_escape(url)}</res></item></DIDL-Lite>';
    await _av(
      tv,
      'SetAVTransportURI',
      '<CurrentURI>${_escape(url)}</CurrentURI>'
          '<CurrentURIMetaData>${_escape(didl)}</CurrentURIMetaData>',
    );
    // Si el TV aún está cargando puede rechazar este Play: se reintenta abajo.
    await _tryAv(tv, 'Play', '<Speed>1</Speed>');
    // Confirmar que el TV realmente arrancó; si no, el usuario vería
    // "Conectado" con la pantalla del TV vacía.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final state = (await status(tv))?.state;
      if (state == 'PLAYING') {
        if (position > const Duration(seconds: 5)) await seek(tv, position);
        return;
      }
      if (state == 'STOPPED' || state == 'NO_MEDIA_PRESENT') {
        // Algunos TV quedan en STOPPED hasta recibir un segundo Play.
        await _tryAv(tv, 'Play', '<Speed>1</Speed>');
      }
    }
    throw const DlnaException(
      'El televisor no empezó a reproducir. Puede que no admita este formato.',
    );
  }

  Future<void> play(DlnaRenderer tv) => _av(tv, 'Play', '<Speed>1</Speed>');
  Future<void> pause(DlnaRenderer tv) => _av(tv, 'Pause', '');
  Future<void> stop(DlnaRenderer tv) => _tryAv(tv, 'Stop', '');

  Future<void> seek(DlnaRenderer tv, Duration position) => _av(
    tv,
    'Seek',
    '<Unit>REL_TIME</Unit><Target>${formatTime(position)}</Target>',
  );

  Future<DlnaStatus?> status(DlnaRenderer tv) async {
    try {
      final transport = await _av(tv, 'GetTransportInfo', '');
      final info = await _av(tv, 'GetPositionInfo', '');
      return (
        state: _value(transport, 'CurrentTransportState') ?? 'UNKNOWN',
        position: parseTime(_value(info, 'RelTime')),
        duration: parseTime(_value(info, 'TrackDuration')),
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> volume(DlnaRenderer tv) async {
    final url = tv.renderingControlUrl;
    if (url == null) return null;
    try {
      final body = await _soap(
        url,
        _renderingControl,
        'GetVolume',
        '<InstanceID>0</InstanceID><Channel>Master</Channel>',
      );
      return int.tryParse(_value(body, 'CurrentVolume') ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> setVolume(DlnaRenderer tv, int value) async {
    final url = tv.renderingControlUrl;
    if (url == null) return;
    await _soap(
      url,
      _renderingControl,
      'SetVolume',
      '<InstanceID>0</InstanceID><Channel>Master</Channel>'
          '<DesiredVolume>${value.clamp(0, 100)}</DesiredVolume>',
    );
  }

  Future<String> _av(DlnaRenderer tv, String action, String args) => _soap(
    tv.avTransportUrl,
    _avTransport,
    action,
    '<InstanceID>0</InstanceID>$args',
  );

  Future<void> _tryAv(DlnaRenderer tv, String action, String args) async {
    try {
      await _av(tv, action, args);
    } catch (_) {}
  }

  Future<String> _soap(
    Uri url,
    String service,
    String action,
    String args,
  ) async {
    final body =
        '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action xmlns:u="$service">$args</u:$action></s:Body>'
        '</s:Envelope>';
    final http.Response res;
    try {
      res = await http
          .post(
            url,
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPAction': '"$service#$action"',
            },
            body: utf8.encode(body),
          )
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const DlnaException('El televisor no respondió.');
    } on SocketException {
      throw const DlnaException(
        'No se pudo conectar con el televisor. ¿Sigue encendido y en la '
        'misma red Wi-Fi?',
      );
    }
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode != 200) {
      final detail = _value(text, 'errorDescription');
      throw DlnaException(
        'El televisor rechazó la orden ($action'
        '${detail == null ? '' : ': $detail'}).',
      );
    }
    return text;
  }

  static String? _value(String xml, String name) {
    final m = RegExp(
      '<(?:\\w+:)?$name[^>]*>([\\s\\S]*?)</(?:\\w+:)?$name>',
    ).firstMatch(xml);
    return m == null ? null : _unescape(m.group(1)!.trim());
  }

  @visibleForTesting
  static Duration parseTime(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 3) return Duration.zero;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = double.tryParse(parts[2]) ?? 0;
    return Duration(milliseconds: ((h * 3600 + m * 60 + s) * 1000).round());
  }

  @visibleForTesting
  static String formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');
