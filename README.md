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

## Catálogo remoto

Puedes hospedar `sources.json` en GitHub Raw o en cualquier hosting estático y
pegar su URL en **Ajustes → Metadata → URL del catálogo remoto**. Usa el mismo
formato de `assets/data/sources.json`, generado por `agregar_fuentes.py`.

El servidor publica el catálogo —nombres, carátulas y URLs de las fuentes—,
no los videos. Si la descarga falla, la app usa la última copia válida guardada
y, si no existe, vuelve al catálogo incluido en el APK.

## Panel de administración

El panel está en `admin/index.html` y es una página HTML/CSS/JS autónoma. Puede
abrirse localmente con doble clic o publicarse en una URL fija de Vercel; no
necesita dependencias, instalación ni paso de compilación.

### Publicar en Vercel

1. Entra en [vercel.com](https://vercel.com) e inicia sesión.
2. Pulsa **Add New Project**.
3. Importa este repositorio desde GitHub.
4. En la configuración del proyecto, abre **Root Directory** y selecciona
   `admin`.
5. Deja **Framework Preset** en **Other** y **Build Command** vacío.
6. Pulsa **Deploy**.

Después del primer despliegue, el panel queda disponible en una URL fija. Cada
`git push` que incluya cambios en `admin/` genera y publica automáticamente
un nuevo despliegue; ya no hace falta buscar ni abrir el archivo local cada vez.

El token fine-grained de GitHub se guarda únicamente en `localStorage` del
navegador bajo la clave `hourtv_admin_cfg`. No se configura como variable de
entorno de Vercel y nunca se guarda en el repositorio. Como el almacenamiento
pertenece al origen de la página, hay que introducir el token una vez en la URL
desplegada aunque ya se hubiera configurado al abrir el archivo local.

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
