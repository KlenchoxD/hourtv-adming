/*
 * Flujo Stalker/Ministra adaptado de IPTVnator:
 * https://github.com/4gray/iptvnator (licencia MIT).
 *
 * En M3UList, las fuentes category == 'stalker' guardan la URL del portal en
 * host y la MAC en username. No se usa password para este tipo de fuente.
 */
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/channel.dart';

class StalkerValidation {
  final bool authenticated;
  final String message;

  const StalkerValidation({required this.authenticated, required this.message});
}

class StalkerService {
  static const String magUserAgent =
      'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 '
      '(KHTML, like Gecko) MAG250';
  static const String _serialNumber = 'BEDACD4569BAF';
  static final Map<String, Future<_StalkerSession>> _sessions = {};

  static String normalizeMac(String mac) => mac.trim().toUpperCase();

  static bool isValidMac(String mac) =>
      RegExp(r'^[0-9A-F]{2}(?::[0-9A-F]{2}){5}$').hasMatch(normalizeMac(mac));

  /// Convierte URLs habituales (.../c, .../stalker_portal/c) al endpoint API.
  static String normalizePortal(String portal) {
    var value = portal.trim();
    if (value.isEmpty) return value;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority) return value;
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.endsWith('/server/load.php')) {
      return uri.replace(query: null, fragment: null, path: path).toString();
    }
    if (path.endsWith('/c')) path = path.substring(0, path.length - 2);
    path = path.isEmpty ? '/server/load.php' : '$path/server/load.php';
    return uri.replace(query: null, fragment: null, path: path).toString();
  }

  static Future<StalkerValidation> validate(String portal, String mac) async {
    if (!isValidMac(mac)) {
      return const StalkerValidation(
        authenticated: false,
        message: 'La MAC debe tener el formato 00:1A:79:XX:XX:XX.',
      );
    }
    try {
      await _getSession(portal, mac, force: true);
      return const StalkerValidation(
        authenticated: true,
        message: 'Portal Stalker conectado.',
      );
    } on TimeoutException {
      return const StalkerValidation(
        authenticated: false,
        message: 'El portal tardó demasiado en responder.',
      );
    } catch (_) {
      return const StalkerValidation(
        authenticated: false,
        message: 'No se pudo autenticar. Revisa la URL y la MAC.',
      );
    }
  }

  static Future<List<Channel>> fetchChannels(
    String portal,
    String mac, {
    String? sourceName,
  }) async {
    final session = await _getSession(portal, mac);
    final genresData = await _request(session, const {
      'type': 'itv',
      'action': 'get_genres',
    });
    final genres = <String, String>{};
    for (final item in _asList(_js(genresData))) {
      if (item is! Map) continue;
      final id = (item['id'] ?? '').toString();
      final title = (item['title'] ?? item['name'] ?? '').toString().trim();
      if (id.isNotEmpty && title.isNotEmpty) genres[id] = title;
    }

    final channelsData = await _request(session, const {
      'type': 'itv',
      'action': 'get_all_channels',
    });
    final channels = <Channel>[];
    for (final item in _asList(_js(channelsData))) {
      if (item is! Map) continue;
      final cmd = (item['cmd'] ?? '').toString().trim();
      if (cmd.isEmpty) continue;
      final id = (item['id'] ?? item['ch_id'] ?? '').toString();
      final genreId = (item['tv_genre_id'] ?? item['genre_id'] ?? '')
          .toString();
      final genre = genres[genreId] ?? sourceName ?? 'Stalker';
      final rawLogo = (item['logo'] ?? '').toString().trim();
      channels.add(
        Channel(
          name: (item['name'] ?? 'Canal').toString(),
          url: _playbackReference(session.endpoint, session.mac, cmd),
          logo: rawLogo.isEmpty
              ? null
              : _absoluteUrl(session.endpoint, rawLogo),
          group: genre,
          genre: genre,
          category: 'stalker',
          tvgId: (item['xmltv_id'] ?? id).toString(),
          tvgName: (item['name'] ?? '').toString(),
          userAgent: magUserAgent,
        ),
      );
    }
    return channels;
  }

  /// Resuelve el marcador persistente justo antes de abrir el reproductor.
  static Future<String?> resolveStream(String reference) async {
    if (!reference.startsWith('stalker:')) return reference;
    try {
      final data = _decodeReference(reference);
      final portal = data['portal']?.toString() ?? '';
      final mac = data['mac']?.toString() ?? '';
      final cmd = data['cmd']?.toString() ?? '';
      if (portal.isEmpty || mac.isEmpty || cmd.isEmpty) return null;
      try {
        return await _createLink(await _getSession(portal, mac), cmd);
      } catch (_) {
        return _createLink(await _getSession(portal, mac, force: true), cmd);
      }
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _createLink(
    _StalkerSession session,
    String cmd,
  ) async {
    final data = await _request(session, {
      'type': 'itv',
      'action': 'create_link',
      'cmd': cmd,
      'series': '0',
      'forced_storage': 'undefined',
      'disable_ad': '0',
      'download': '0',
    });
    final js = _js(data);
    final raw = js is Map ? (js['cmd'] ?? js['url']) : js;
    if (raw == null) return null;
    final url = raw.toString().trim().replaceFirst(
      RegExp(r'^(?:ffmpeg|auto)\s+', caseSensitive: false),
      '',
    );
    return url.startsWith('http://') || url.startsWith('https://') ? url : null;
  }

  static Future<_StalkerSession> _getSession(
    String portal,
    String mac, {
    bool force = false,
  }) {
    final endpoint = normalizePortal(portal);
    final normalizedMac = normalizeMac(mac);
    final key = '$endpoint|$normalizedMac';
    if (force) _sessions.remove(key);
    return _sessions.putIfAbsent(
      key,
      () => _authenticate(endpoint, normalizedMac),
    );
  }

  static Future<_StalkerSession> _authenticate(
    String endpoint,
    String mac,
  ) async {
    if (endpoint.isEmpty || !isValidMac(mac)) {
      throw const FormatException('Portal o MAC inválidos.');
    }
    final prehash = _sha1Hex(mac).toUpperCase();
    final temporary = _StalkerSession(endpoint: endpoint, mac: mac);
    final handshake = await _request(temporary, {
      'type': 'stb',
      'action': 'handshake',
      'token': '',
      'prehash': prehash,
    });
    final handshakeJs = _js(handshake);
    if (handshakeJs is! Map) throw const FormatException('Handshake inválido.');
    final token = (handshakeJs['token'] ?? '').toString();
    final random = (handshakeJs['random'] ?? '').toString();
    if (token.isEmpty) {
      throw const FormatException('El portal no devolvió token.');
    }
    final session = _StalkerSession(
      endpoint: endpoint,
      mac: mac,
      token: token,
      random: random,
    );
    final deviceId = _sha1Hex(mac).toUpperCase();
    final metrics = jsonEncode({
      'mac': mac,
      'model': 'MAG250',
      'type': 'STB',
      'random': random,
      'sn': _serialNumber,
    });
    final profile = await _request(session, {
      'type': 'stb',
      'action': 'get_profile',
      'hd': '1',
      'not_valid_token': '0',
      'video_out': 'hdmi',
      'auth_second_step': '1',
      'num_banks': '2',
      'metrics': metrics,
      'sn': _serialNumber,
      'device_id': deviceId,
      'device_id2': deviceId,
      'signature': _sha1Hex('$random$mac').toUpperCase(),
      'prehash': prehash,
      'stb_type': 'MAG250',
    });
    if (_js(profile) == null) throw const FormatException('Perfil inválido.');
    return session;
  }

  static Future<dynamic> _request(
    _StalkerSession session,
    Map<String, String> parameters,
  ) async {
    final uri = Uri.parse(
      session.endpoint,
    ).replace(queryParameters: {...parameters, 'JsHttpRequest': '1-xml'});
    final headers = <String, String>{
      'Accept': '*/*',
      'Cookie':
          'mac=${Uri.encodeComponent(session.mac)}; stb_lang=es_ES; timezone=GMT',
      'User-Agent': magUserAgent,
      'X-User-Agent': 'Model: MAG250; Link: WiFi',
    };
    if (session.token.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.token}';
    }
    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static dynamic _js(dynamic value) => value is Map ? value['js'] : null;

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map && value['data'] is List) {
      return List<dynamic>.from(value['data'] as List);
    }
    return const [];
  }

  static String _playbackReference(String portal, String mac, String cmd) {
    final json = jsonEncode({'portal': portal, 'mac': mac, 'cmd': cmd});
    return 'stalker:${base64Url.encode(utf8.encode(json)).replaceAll('=', '')}';
  }

  static Map<String, dynamic> _decodeReference(String reference) {
    var encoded = reference.substring('stalker:'.length);
    while (encoded.length % 4 != 0) {
      encoded += '=';
    }
    final value = jsonDecode(utf8.decode(base64Url.decode(encoded)));
    if (value is! Map) throw const FormatException('Referencia inválida.');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _absoluteUrl(String endpoint, String value) {
    final uri = Uri.tryParse(value);
    if (uri?.hasAuthority == true) return value;
    final base = Uri.parse(endpoint);
    return base.resolve(value).toString();
  }

  // SHA-1 pequeño para los identificadores MAG; evita otra dependencia runtime.
  static String _sha1Hex(String input) {
    final bytes = Uint8List.fromList(utf8.encode(input));
    final bitLength = bytes.length * 8;
    final paddedLength = ((bytes.length + 9 + 63) ~/ 64) * 64;
    final padded = Uint8List(paddedLength)..setAll(0, bytes);
    padded[bytes.length] = 0x80;
    final data = ByteData.sublistView(padded);
    data.setUint32(paddedLength - 8, bitLength ~/ 0x100000000);
    data.setUint32(paddedLength - 4, bitLength & 0xffffffff);
    var h0 = 0x67452301;
    var h1 = 0xefcdab89;
    var h2 = 0x98badcfe;
    var h3 = 0x10325476;
    var h4 = 0xc3d2e1f0;
    int rol(int value, int count) =>
        ((value << count) | ((value & 0xffffffff) >> (32 - count))) &
        0xffffffff;
    for (var offset = 0; offset < paddedLength; offset += 64) {
      final w = List<int>.filled(80, 0);
      for (var i = 0; i < 16; i++) {
        w[i] = data.getUint32(offset + i * 4);
      }
      for (var i = 16; i < 80; i++) {
        w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }
      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      for (var i = 0; i < 80; i++) {
        late int f;
        late int k;
        if (i < 20) {
          f = (b & c) | ((~b) & d);
          k = 0x5a827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ed9eba1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8f1bbcdc;
        } else {
          f = b ^ c ^ d;
          k = 0xca62c1d6;
        }
        final temp = (rol(a, 5) + f + e + k + w[i]) & 0xffffffff;
        e = d;
        d = c;
        c = rol(b, 30);
        b = a;
        a = temp;
      }
      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
    }
    return [
      h0,
      h1,
      h2,
      h3,
      h4,
    ].map((value) => value.toRadixString(16).padLeft(8, '0')).join();
  }
}

class _StalkerSession {
  final String endpoint;
  final String mac;
  final String token;
  final String random;

  const _StalkerSession({
    required this.endpoint,
    required this.mac,
    this.token = '',
    this.random = '',
  });
}
