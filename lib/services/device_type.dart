import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DeviceType { phone, tablet, desktop, tv }

/// Detecta el tipo de dispositivo y mantiene separados los cuatro diseños.
class DeviceProfile {
  static const _channel = MethodChannel('hourtv/device');
  static bool? _isTvCache;

  static Future<bool> _isAndroidTv() async {
    if (_isTvCache != null) return _isTvCache!;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _isTvCache = false;
    }
    try {
      _isTvCache = await _channel.invokeMethod<bool>('isTv') ?? false;
    } catch (_) {
      _isTvCache = false;
    }
    return _isTvCache!;
  }

  static Future<void> warmUp() => _isAndroidTv();

  static DeviceType of(BuildContext context) {
    if (_isTvCache == true) return DeviceType.tv;
    final size = MediaQuery.sizeOf(context);

    // En navegador no existe dart:io. El ancho visible permite comprobar los
    // mismos cuatro diseños desde localhost sin romper Android/TV nativos.
    if (kIsWeb) {
      if (size.width >= 1100) return DeviceType.desktop;
      return size.shortestSide >= 600 ? DeviceType.tablet : DeviceType.phone;
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return DeviceType.desktop;
    }

    return size.shortestSide >= 600 ? DeviceType.tablet : DeviceType.phone;
  }

  static bool isTv(BuildContext context) => of(context) == DeviceType.tv;
  static bool isDesktop(BuildContext context) =>
      of(context) == DeviceType.desktop;
  static bool isTablet(BuildContext context) =>
      of(context) == DeviceType.tablet;
  static bool isPhone(BuildContext context) => of(context) == DeviceType.phone;

  static bool isRemoteOnly(BuildContext context) => isTv(context);

  static double uiScale(BuildContext context) => switch (of(context)) {
    DeviceType.tv => 1.5,
    DeviceType.desktop => 1.0,
    DeviceType.tablet => 1.15,
    DeviceType.phone => 1.0,
  };

  static double overscan(BuildContext context) => isTv(context) ? 24.0 : 0.0;
}
