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
    if (!isEnabled) return items;
    return items.where((item) => !isAdultChannel(item)).toList(growable: false);
  }

  static List<XtreamSeries> filterSeries(Iterable<XtreamSeries> series) {
    final items = series.toList(growable: false);
    if (!isEnabled) return items;
    return items.where((item) => !isAdultSeries(item)).toList(growable: false);
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
