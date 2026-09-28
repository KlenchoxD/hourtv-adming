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

  static Future<String?>? _countryIso;

  /// País (ISO, minúsculas) de la red móvil o la SIM; null si no hay. El
  /// idioma del teléfono no sirve: en Latinoamérica suele ser "es-US".
  static Future<String?> countryIso() => _countryIso ??= () async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final iso = await _channel.invokeMethod<String>('countryIso');
      return (iso == null || iso.isEmpty) ? null : iso;
    } catch (_) {
      return null;
    }
  }();

  static DeviceType of(BuildContext context) {
    if (overrideType.value != null) return overrideType.value!;
    if (_isTvCache == true) return DeviceType.tv;
    final size = MediaQuery.sizeOf(context);

    // En navegador el diseño sale del equipo real: ?mode=tv|tablet|phone fuerza
    // uno (pruebas); celulares y tablets (Android/iOS, iPad) por su lado
    // corto, como en la app; lo demás es computador.
    if (kIsWeb) {
      final mode =
          Uri.base.queryParameters['mode'] ?? Uri.base.queryParameters['view'];
      if (mode == 'tv') return DeviceType.tv;
      if (mode == 'phone') return DeviceType.phone;
      if (mode == 'tablet') return DeviceType.tablet;
      final touchOs =
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      if (touchOs) {
        return size.shortestSide < 600 ? DeviceType.phone : DeviceType.tablet;
      }
      // En computador cuenta el ancho: una ventana angosta es como un celular
      // (una ventana baja pero ancha sigue siendo computador).
      return size.width < 600 ? DeviceType.phone : DeviceType.desktop;
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return DeviceType.desktop;
    }

    return size.shortestSide >= 600 ? DeviceType.tablet : DeviceType.phone;
  }

  /// Orientaciones de la app fuera del reproductor: en teléfono siempre
  /// vertical (como Xuper), aunque el teléfono tenga el giro automático
  /// activado; en tablet y TV, cualquiera.
  static List<DeviceOrientation> appOrientations() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty || _isTvCache == true) return _anyOrientation;
    final view = views.first;
    final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
    return shortest > 0 && shortest < 600
        ? const [DeviceOrientation.portraitUp]
        : _anyOrientation;
  }

  static const _anyOrientation = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

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
