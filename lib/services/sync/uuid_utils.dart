import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Utilidad pura en Dart para generación de identificadores UUID v4 (aleatorios)
/// y v5 (deterministas basados en SHA-1 conforme a RFC 4122).
class UuidUtils {
  static final Random _random = Random.secure();

  /// Namespace predeterminado RFC 4122 para URLs / contenido HourTV
  static const String namespaceUrl = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';

  /// Genera un UUID v4 criptográficamente seguro (RFC 4122)
  static String v4([Random? customRandom]) {
    final rng = customRandom ?? _random;
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

    // Versión 4 (0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variante RFC 4122 (10xx)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    return _formatBytesAsUuid(bytes);
  }

  /// Genera un UUID v5 determinista basado en SHA-1 (RFC 4122)
  static String v5(String namespace, String name) {
    final namespaceBytes = _parseUuidToBytes(namespace);
    final nameBytes = utf8.encode(name);

    final toHash = <int>[...namespaceBytes, ...nameBytes];
    final digest = sha1.convert(toHash).bytes;

    final bytes = digest.sublist(0, 16);
    // Versión 5 (0101)
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    // Variante RFC 4122 (10xx)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    return _formatBytesAsUuid(bytes);
  }

  static List<int> _parseUuidToBytes(String uuid) {
    final hex = uuid.replaceAll('-', '');
    if (hex.length != 32) {
      throw ArgumentError('UUID inválido para namespace: $uuid');
    }
    final bytes = <int>[];
    for (int i = 0; i < 32; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static String _formatBytesAsUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
