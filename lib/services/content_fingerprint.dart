/// Huella FNV-1a de 64 bits de un contenido descargado (catálogo, listas).
/// Sirve para saber si lo que llegó de la red es idéntico a lo que produjo
/// la caché local, sin comparar objetos. Solo en nativo: en web los enteros
/// son doubles y el producto pierde precisión (quien la use debe ignorarla).
int fingerprintBytes(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final b in bytes) {
    hash ^= b;
    hash *= 0x100000001b3;
  }
  return hash ^ bytes.length;
}

int fingerprintString(String value) {
  var hash = 0xcbf29ce484222325;
  for (var i = 0; i < value.length; i++) {
    hash ^= value.codeUnitAt(i);
    hash *= 0x100000001b3;
  }
  return hash ^ value.length;
}

/// Combina huellas en orden (el orden importa: cambia el catálogo final).
int combineFingerprints(Iterable<Object?> parts) {
  var hash = 0xcbf29ce484222325;
  for (final part in parts) {
    final h = part is int ? part : fingerprintString('$part');
    hash ^= h;
    hash *= 0x100000001b3;
  }
  return hash;
}
