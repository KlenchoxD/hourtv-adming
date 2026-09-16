import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DeviceType { phone, tablet, desktop, tv }

/// Detecta el tipo de dispositivo y mantiene separados los cuatro diseños.
class DeviceProfile {
  static const _channel = MethodChannel('hourtv/device');
  static bool? _isTvCache;
  static final ValueNotifier<DeviceType?> overrideType =
      ValueNotifier<DeviceType?>(null);

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
    if (overrideType.value != null) return overrideType.value!;
    if (_isTvCache == true) return DeviceType.tv;
    final size = MediaQuery.sizeOf(context);

    // En navegador, por defecto mostramos el diseño móvil de Android para pruebas
    // del app móvil, con soporte para alternar a TV mediante query o toggle.
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.queryParameters['mode'] == 'tv' ||
          uri.queryParameters['view'] == 'tv') {
        return DeviceType.tv;
      }
      if (uri.queryParameters['mode'] == 'tablet' ||
          uri.queryParameters['view'] == 'tablet') {
        return DeviceType.tablet;
      }
      return DeviceType.phone;
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
}

enum AdaptiveLayoutSize { compact, medium, expanded }

enum AdaptiveInputMode { touch, pointer, dpad }

class AdaptiveProfileData {
  const AdaptiveProfileData({
    required this.layoutSize,
    required this.inputMode,
    required this.deviceType,
  });

  final AdaptiveLayoutSize layoutSize;
  final AdaptiveInputMode inputMode;
  final DeviceType deviceType;

  bool get isCompact => layoutSize == AdaptiveLayoutSize.compact;
  bool get isMedium => layoutSize == AdaptiveLayoutSize.medium;
  bool get isExpanded => layoutSize == AdaptiveLayoutSize.expanded;

  bool get isTouch => inputMode == AdaptiveInputMode.touch;
  bool get isPointer => inputMode == AdaptiveInputMode.pointer;
  bool get isDpad => inputMode == AdaptiveInputMode.dpad;
}

class AdaptiveProfile {
  static final ValueNotifier<AdaptiveLayoutSize?> overrideLayoutSize =
      ValueNotifier<AdaptiveLayoutSize?>(null);
  static final ValueNotifier<AdaptiveInputMode?> overrideInputMode =
      ValueNotifier<AdaptiveInputMode?>(null);

  static AdaptiveProfileData of(BuildContext context) {
    final devType = DeviceProfile.of(context);
    final size = MediaQuery.sizeOf(context);

    final AdaptiveLayoutSize layoutSize;
    if (overrideLayoutSize.value != null) {
      layoutSize = overrideLayoutSize.value!;
    } else if (size.width < 600) {
      layoutSize = AdaptiveLayoutSize.compact;
    } else if (size.width < 1024) {
      layoutSize = AdaptiveLayoutSize.medium;
    } else {
      layoutSize = AdaptiveLayoutSize.expanded;
    }

    final AdaptiveInputMode inputMode;
    if (overrideInputMode.value != null) {
      inputMode = overrideInputMode.value!;
    } else if (devType == DeviceType.tv) {
      inputMode = AdaptiveInputMode.dpad;
    } else if (kIsWeb) {
      inputMode = AdaptiveInputMode.pointer;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      inputMode = AdaptiveInputMode.pointer;
    } else {
      inputMode = AdaptiveInputMode.touch;
    }

    return AdaptiveProfileData(
      layoutSize: layoutSize,
      inputMode: inputMode,
      deviceType: devType,
    );
  }
}
