import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/channel.dart';
import 'storage_service.dart';
import 'xtream_service.dart';

/// Single source of truth for HourTV restricted mode.
///
/// Catalog data is never deleted: filtering happens only at the public read
/// boundary. A numeric PIN is stored as a SHA-256 digest, never as plain text.
abstract final class ParentalControlService {
  static const enabledKey = 'parentalControlEnabled';
  static const pinHashKey = 'parentalControlPinHash';

  static bool get isEnabled =>
      StorageService.getSetting(enabledKey, defaultValue: false) == true;

  /// Perfil infantil activo: solo se muestra contenido para niños.
  static bool get kidsOnly => StorageService.activeProfileIsKids;

  /// Cambia cuando cambia lo que se filtra (para invalidar cachés).
  static int get filterMode => (isEnabled ? 1 : 0) | (kidsOnly ? 2 : 0);

  static bool get hasPin {
    final value = StorageService.getSetting(pinHashKey, defaultValue: '');
    return value is String && value.isNotEmpty;
  }

  static Future<void> enable(String pin) async {
    _validatePin(pin);
    await StorageService.saveSetting(pinHashKey, _hash(pin));
    await StorageService.saveSetting(enabledKey, true);
  }

  static Future<void> disable(String pin) async {
    if (!verifyPin(pin)) throw const ParentalPinException();
    await StorageService.saveSetting(enabledKey, false);
  }

  static bool verifyPin(String pin) {
    final stored = StorageService.getSetting(pinHashKey, defaultValue: '');
    return stored is String && stored.isNotEmpty && stored == _hash(pin);
  }

  static List<Channel> filterChannels(Iterable<Channel> channels) {
    final items = channels.toList(growable: false);
    if (kidsOnly) {
      return items.where(isKidsChannel).toList(growable: false);
    }
    if (!isEnabled) return items;
    return items.where((item) => !isAdultChannel(item)).toList(growable: false);
  }

  static List<XtreamSeries> filterSeries(Iterable<XtreamSeries> series) {
    final items = series.toList(growable: false);
    if (kidsOnly) {
      return items.where(isKidsSeries).toList(growable: false);
    }
    if (!isEnabled) return items;
    return items.where((item) => !isAdultSeries(item)).toList(growable: false);
  }

  // ── Perfil infantil ────────────────────────────────────────────────────
  // Como la sección "Infantil" de Xuper (por géneros), pero más estricta:
  // allí se cuelan títulos de terror animados. Aquí un título entra solo si
  // es infantil/animación/familia Y no tiene ningún género no apto.

  /// Película, serie o canal en vivo apto para el perfil infantil.
  static bool isKidsChannel(Channel channel) {
    if (channel.isKidsSafe) return true;
    if (isAdultChannel(channel)) return false;
    if (channel.type == MediaType.live) {
      return _hasKidsLiveMarker([
        channel.name,
        channel.group,
        channel.category,
        channel.genre,
        ...channel.categories,
      ]);
    }
    return _isKidsTagged(
      genres: [channel.genre, channel.group, channel.category],
      categories: channel.categories,
    );
  }

  static bool isKidsSeries(XtreamSeries series) {
    if (isAdultSeries(series)) return false;
    return _isKidsTagged(genres: [series.genre], categories: series.categories);
  }

  // "Animación" sola no basta (Hazbin Hotel, Invencible...): TMDB marca con
  // "Familia" casi toda la animación para niños.
  static const _kidsMarkers = [
    'infantil',
    'familia',
    'familiar',
    'kids',
    'ninos',
    'disney',
    'pixar',
    'dibujos',
    'cartoon',
  ];

  // Nunca aptos, aunque sean animados o de familia.
  static const _hardBlocked = [
    'terror',
    'horror',
    'gore',
    'thriller',
    'belica',
    'guerra',
    'war',
  ];

  // Aptos solo si además son de familia/infantiles (Minions: El origen de
  // Gru tiene "Crimen"; Scooby-Doo, "Misterio"; Tokyo Ghoul no pasa).
  static const _softBlocked = [
    'crimen',
    'crime',
    'suspense',
    'suspenso',
    'anime',
    'misterio',
  ];

  // Nombres/grupos de canales infantiles (Disney Junior, Nick Jr, Cartoon
  // Network, Discovery Kids, BabyTV, Clan...). Una sola RegExp compilada.
  static final _liveKidsMarker = RegExp(
    r'(^|[^a-z])(infantil|kids|ninos|cartoon|disney|nick|boomerang|baby|junior|dibujos|tooncast|zoomoo|clan)',
  );

  static bool _isKidsTagged({
    required Iterable<String?> genres,
    required Iterable<String?> categories,
  }) {
    final genreTags = _normalizedTags(genres);
    final categoryTags = _normalizedTags(categories);
    final tags = [...genreTags, ...categoryTags];
    bool hasIn(List<String> list, String marker) =>
        list.any((tag) => tag.contains(marker));
    bool has(String marker) => hasIn(tags, marker);
    if (!_kidsMarkers.any(has)) return false;
    // El panel etiqueta "terror" a títulos infantiles de Halloween/Scooby-Doo:
    // esa categoría no bloquea si el título también está en "infantil". Si
    // el género dice terror, bloquea siempre.
    final kidsCategory = hasIn(categoryTags, 'infantil');
    for (final marker in _hardBlocked) {
      if (hasIn(genreTags, marker)) return false;
      if (!kidsCategory && hasIn(categoryTags, marker)) return false;
    }
    final forFamily = has('infantil') || has('familia') || has('familiar');
    if (!forFamily && _softBlocked.any(has)) return false;
    return true;
  }

  static bool _hasKidsLiveMarker(Iterable<String?> values) =>
      _normalizedTags(values).any(_liveKidsMarker.hasMatch);

  static List<String> _normalizedTags(Iterable<String?> values) => [
    for (final raw in values)
      if (raw != null && raw.trim().isNotEmpty)
        _stripAccents(raw.toLowerCase()),
  ];

  static String _stripAccents(String value) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString();
  }

  static bool isAdultChannel(Channel channel) => _containsAdultMarker([
    channel.rating,
    channel.genre,
    channel.group,
    channel.category,
    ...channel.categories,
  ]);

  static bool isAdultSeries(XtreamSeries series) =>
      _containsAdultMarker([series.rating, series.genre, ...series.categories]);

  // Compiladas una sola vez: antes se construian dentro del bucle, o sea tres
  // RegExp nuevas por cada campo de cada canal en cada filtrado. Con un
  // catalogo grande eso es lo que hacia que activar el modo restringido
  // congelara la interfaz.
  static final _ageMarker = RegExp(r'(^|[^0-9])(18|21)\s*\+?([^0-9]|$)');
  static final _ratingMarker = RegExp(r'\b(tv[- ]?ma|nc[- ]?17|rated\s*r)\b');
  static final _wordMarker = RegExp(
    r'(^|[^a-z])(adult|adulto|adultos|mature|xxx|erotica|erótico|erotico)([^a-z]|$)',
  );

  static bool _containsAdultMarker(Iterable<String?> values) {
    for (final raw in values) {
      if (raw == null) continue;
      final value = raw.trim().toLowerCase();
      if (value.isEmpty) continue;

      if (_ageMarker.hasMatch(value) ||
          _ratingMarker.hasMatch(value) ||
          _wordMarker.hasMatch(value)) {
        return true;
      }
    }
    return false;
  }

  static void _validatePin(String pin) {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw ArgumentError.value(
        pin,
        'pin',
        'Debe contener entre 4 y 6 dígitos',
      );
    }
  }

  static String _hash(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();
}

class ParentalPinException implements Exception {
  const ParentalPinException();

  @override
  String toString() => 'PIN parental incorrecto';
}
