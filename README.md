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
no los videos. La app muestra primero la última copia válida y los canales ya
parseados, sin esperar la red; después revalida en segundo plano. Si no existe
caché local, vuelve al catálogo incluido en el APK.

## Panel de administración

El panel está en `admin/index.html` y es una página HTML/CSS/JS autónoma. Puede
abrirse localmente con doble clic o publicarse en una URL fija de Vercel; no
necesita dependencias, instalación ni paso de compilación.

El editor administra únicamente películas y series de Inicio. Los canales En Vivo y las fuentes IPTV no se crean ni se modifican desde este panel.

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

## APK release universal

`flutter build apk --release` genera un único
`build/app/outputs/flutter-apk/app-release.apk` sin `--split-per-abi`. Incluye
armeabi-v7a, arm64-v8a y x86_64. Flutter 3.44.6 establece como mínimo
Android 7.0 (API 24); el propio SDK migra automáticamente valores 21–23 a 24,
por lo que bajar más requiere usar y mantener una versión anterior de Flutter.

## Instalar en TV por pendrive USB

1. Compila `flutter build apk --release` y copia
   `build/app/outputs/flutter-apk/app-release.apk` a un pendrive.
2. Conecta el pendrive al TV o TV-Box y abre el APK con su explorador de
   archivos.
3. Cuando Android lo solicite, habilita **Instalar aplicaciones desconocidas**
   para ese explorador.
4. Confirma **Instalar** y abre HourTV desde el launcher. No se necesita Play
   Store ni una compilación diferente para TV.

## Transmitir al TV

El botón **Transmitir** del reproductor VOD descubre receptores Chromecast y
Google TV en la red local y envía directamente la URL HLS (`.m3u8`) o MP4 al
Default Media Receiver de Google Cast (`CC1AD845`). La app pausa el reproductor
local y muestra controles remotos de reproducción, pausa, búsqueda, volumen y
desconexión.

El receptor debe poder acceder a la URL y el servidor debe permitir Cast/CORS.
El Default Media Receiver no admite un `User-Agent` HTTP personalizado; para
esas fuentes HourTV informa la incompatibilidad y ofrece **Compartir pantalla**
como alternativa desde las opciones del reproductor. Cast permanece limitado
a VOD; los canales En Vivo no muestran este botón.

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
