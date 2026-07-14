import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DeviceType { phone, tablet, tv }

/// Detecta el tipo de dispositivo para adaptar navegación e interfaz.
///
/// TV se detecta con `UiModeManager` nativo (Android TV / Google TV / TV Box
/// reportan `UI_MODE_TYPE_TELEVISION`), no por tamaño de pantalla: un TV Box
/// puede reportar resoluciones iguales a una tablet grande. Phone vs tablet
/// sí se distingue por ancho, siguiendo el breakpoint estándar de Material
/// (600dp).
class DeviceProfile {
  static const _channel = MethodChannel('hourtv/device');
  static bool? _isTvCache;

  static Future<bool> _isAndroidTv() async {
    if (_isTvCache != null) return _isTvCache!;
    if (!Platform.isAndroid) return _isTvCache = false;
    try {
      _isTvCache = await _channel.invokeMethod<bool>('isTv') ?? false;
    } catch (_) {
      _isTvCache = false;
    }
    return _isTvCache!;
  }

  /// Debe llamarse una vez al inicio (antes de runApp) para que [of] pueda
  /// resolver de forma síncrona durante el primer build.
  static Future<void> warmUp() => _isAndroidTv();

  static DeviceType of(BuildContext context) {
    if (_isTvCache == true) return DeviceType.tv;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    return shortestSide >= 600 ? DeviceType.tablet : DeviceType.phone;
  }

  static bool isTv(BuildContext context) => of(context) == DeviceType.tv;
  static bool isTablet(BuildContext context) => of(context) == DeviceType.tablet;
  static bool isPhone(BuildContext context) => of(context) == DeviceType.phone;

  /// Dispositivo operado únicamente por control remoto/teclado (sin touch
  /// confiable): hoy coincide con TV, pero se deja separado por si en el
  /// futuro se detecta táctil ausente por otra vía.
  static bool isRemoteOnly(BuildContext context) => isTv(context);
}
