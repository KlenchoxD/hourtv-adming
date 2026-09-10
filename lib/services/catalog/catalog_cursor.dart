import 'dart:convert';

/// Representa el cursor de paginación determinista basado en tupla (createdAt, id).
class CatalogCursor {
  final DateTime createdAt;
  final String id;

  const CatalogCursor({
    required this.createdAt,
    required this.id,
  });

  /// Codifica el cursor a una cadena base64url segura para URLs y APIs.
  String encode() {
    final raw = '${createdAt.toIso8601String()}|$id';
    return base64Url.encode(utf8.encode(raw));
  }

  /// Intenta decodificar una cadena base64url. Retorna null si es inválida,
  /// nula, vacía o con formato corrupto.
  static CatalogCursor? tryDecode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = utf8.decode(base64Url.decode(encoded));
      final parts = decoded.split('|');
      if (parts.length == 2) {
        final date = DateTime.tryParse(parts[0]);
        if (date != null && parts[1].isNotEmpty) {
          return CatalogCursor(createdAt: date, id: parts[1]);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogCursor &&
          runtimeType == other.runtimeType &&
          createdAt == other.createdAt &&
          id == other.id;

  @override
  int get hashCode => createdAt.hashCode ^ id.hashCode;

  @override
  String toString() => 'CatalogCursor(createdAt: $createdAt, id: $id)';
}
