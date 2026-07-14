# HourTV

App IPTV personal (Flutter) para teléfonos, tablets, Android TV, Google TV,
TV Box y Chromecast con Google TV. Es **una sola base de código y un solo
APK/AAB**: el tipo de interfaz (táctil o mando a distancia) se decide en
tiempo de ejecución con `DeviceProfile` (ver [lib/services/device_type.dart](lib/services/device_type.dart)),
no con variantes de compilación separadas.

## Compilar

```bash
flutter pub get
```

**Móvil/tablet — APK debug**
```bash
flutter build apk --debug
# salida: build/app/outputs/flutter-apk/app-debug.apk
```

**Móvil/tablet — APK release**
```bash
flutter build apk --release
# salida: build/app/outputs/flutter-apk/app-release.apk
```

**Google Play — App Bundle**
```bash
flutter build appbundle --release
# salida: build/app/outputs/bundle/release/app-release.aab
```

**Android TV / Google TV / TV Box** — usan el mismo artefacto que móvil
(`app-debug.apk` / `app-release.apk`); el manifiesto ya declara
`LEANBACK_LAUNCHER`, `android.software.leanback` y
`android.hardware.touchscreen` como opcional, así que la app aparece en el
launcher de TV sin necesidad de una compilación aparte.

## Instalar por ADB

```bash
# Teléfono o tablet conectado por USB con depuración habilitada
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Android TV / Google TV / TV Box (conectar antes con adb connect IP:5555
# si es por red en lugar de USB)
adb connect <ip-del-tv>:5555
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Chromecast con Google TV: mismo procedimiento que Google TV (comparten SO)
```

## Verificar en el launcher de TV

1. Abrir el launcher de Android TV / Google TV tras instalar.
2. Buscar "HourTV" en la fila de apps — debe mostrarse con el banner
   horizontal (`android/app/src/main/res/drawable/tv_banner.png`), no con el
   ícono cuadrado de móvil.
3. Abrir la app únicamente con el control remoto (sin tocar la pantalla si
   el TV la tiene) y confirmar que el foco es visible en cada pantalla.

## Arquitectura TV

- `DeviceProfile.isTv(context)` detecta Android TV/Google TV vía
  `UiModeManager` nativo (no por tamaño de pantalla), ver
  [MainActivity.kt](android/app/src/main/kotlin/com/example/mi_app/MainActivity.kt).
- [HomeShell](lib/screens/home_shell.dart) alterna entre barra inferior
  (móvil/tablet) y riel lateral navegable con D-pad (TV).
- [TvFocusable](lib/widgets/tv_focusable.dart) hace foco/D-pad consistente
  en tarjetas, botones y filas en toda la app.
