# Tarea para Codex: HourTV para Web y para computador (Windows)

Eres el ingeniero a cargo de llevar **HourTV** (app Flutter de películas, series y
TV en vivo) al **navegador web** y al **computador (Windows; macOS/Linux solo si
sale gratis)**, con el mismo código base que ya funciona en Android. El dueño del
proyecto (Kleiner) habla español y no es programador: todo lo que le reportes,
en español simple.

Lee este documento completo antes de tocar código.

---

## 1. Reglas que no se negocian

1. **Nada fingido.** Ninguna pantalla, botón, anuncio, reproductor o dato de
   ejemplo que aparente funcionar sin funcionar. Si algo no se puede en una
   plataforma, se oculta o se explica con un mensaje honesto ("Este servidor
   solo se puede ver en la app de Android"), nunca un placeholder.
2. **No romper Android.** Android es la versión publicada (v1.1.28) y genera los
   ingresos. Al terminar cada fase:
   - `flutter test` → todas las pruebas pasan (hoy son 539).
   - `flutter analyze` → sin errores ni advertencias nuevas.
   - `flutter build apk --release --dart-define-from-file=config/supabase.local.json`
     sigue compilando igual.
3. **Compilar siempre con** `--dart-define-from-file=config/supabase.local.json`
   (tiene la URL y la clave *anon* de Supabase; está en `.gitignore`). Sin eso el
   inicio de sesión queda apagado.
4. **Secretos:** nunca subas ni imprimas `config/supabase.local.json`,
   `android/key.properties`, keystores ni claves. En la app solo puede ir la
   clave pública *anon* de Supabase.
5. **Git:** commits pequeños y descriptivos en español están bien. **No hagas
   `push`, no publiques releases ni despliegues la web** sin que Kleiner lo
   apruebe explícitamente.
6. **Supabase:** no ejecutes SQL. Si necesitas algo en la base de datos, escribe
   la migración en `supabase/migrations/` (idempotente) y avisa: la ejecuta otro
   agente (Hermes).
7. **Nada que cueste dinero ni cuentas nuevas** (hosting, CDN, proxys pagos, redes
   de anuncios) sin preguntar primero. Explica opciones con costo real.
8. No escanees la red local desde el PC de desarrollo, no descompiles apps de
   terceros, no instales apps desde anuncios.
9. Estilo: sigue el del código existente (comentarios en español, explican el
   *por qué*; soluciones mínimas; reutiliza lo que ya existe antes de crear algo
   nuevo).

---

## 2. Contexto del proyecto

- **Flutter 3.44.6**, Dart 3. Repo: `KlenchoxD/hourtv-adming` (rama `master`).
  El paquete Dart se llama `streamtv`.
- **Entradas de UI** (ya adaptativas por tipo de dispositivo,
  `lib/services/device_type.dart` → `DeviceProfile.of(context)`):
  - `lib/mobile_ui/hourtv_mobile_shell.dart`: teléfono y tablet.
  - `lib/new_ui/hourtv_new_shell.dart`: TV y **escritorio** (`DeviceType.desktop`
    ya existe: Windows/macOS/Linux). En web hoy devuelve `phone` salvo
    `?mode=tv`/`?mode=tablet`.
- **Catálogo:**
  - Principal: `catalog.json` publicado en
    `https://raw.githubusercontent.com/KlenchoxD/hourtv-adming/master/catalog.json`
    (lo lee `ContentStore`, `lib/services/content_store.dart`, con
    `lib/services/catalog_parser.dart`).
  - Secundario: tablas de Supabase sincronizadas a una base local **Drift**
    (`lib/database/`, `lib/services/catalog/`).
- **Cuentas y sincronización:** Supabase Auth + sincronización de perfiles
  (favoritos, "continuar viendo", historial, Me gusta y ajustes) en
  `lib/services/sync/`. Depende de Drift (`UserDataDao`).
- **Reproductor:** `lib/new_ui/hourtv_player_screen.dart` (`video_player` +
  `chewie`). Detalles:
  - Muchos servidores son **páginas embed** (streamwish, voe, paulinito…) que
    `lib/services/embed_resolver.dart` convierte en `.m3u8`/`.mp4` directo y que
    exigen cabeceras **Referer/User-Agent**.
  - También incluye: selector de calidad HLS, reanudar posición, subtítulos
    (`lib/services/subtitles/`, repositorio `KlenchoxD/hourtv-subtitles`
    servido por `raw.githubusercontent.com`) y estilo de subtítulos.
- **Transmitir a TV (solo Android hoy):** Chromecast
  (`flutter_chrome_cast`) + DLNA (`lib/services/dlna_service.dart`, SSDP por
  UDP) + proxy local con cabeceras (`lib/services/cast_proxy.dart`).
- **Anuncios (solo Android):**
  - Unity LevelPlay (`lib/services/ads/`, plugin `unity_levelplay_mediation`).
  - Se muestra un video obligatorio antes de películas y episodios; en vivo nunca.
- **Actualizaciones (Android):** `lib/services/update_service.dart` descarga
  `HourTV-<versión>.apk` del último release de GitHub.
- **Otros solo-Android:**
  - PiP, orientación y modo inmersivo (`SystemChrome`), `hourtv/device`
    MethodChannel (`MainActivity.kt`), multicast lock.
  - Servidor IPTV local (`iptv_server_service.dart`, usa `dart:io`).
  - Caché de logos en disco (`logo_image_provider.dart`).

## 3. Estado actual verificado (28-sep-2026)

- `web/` y `windows/` (y `macos/`, `linux/`) ya existen.
- **Web NO compila:**
  - `lib/database/catalog_database.dart` importa `package:drift/native.dart`
    (SQLite nativo por FFI).
  - Hay `import 'dart:io'` en 16 archivos: `main.dart`, `catalog_database.dart`,
    `catalog_infrastructure.dart`, `storage_service.dart`, `content_store.dart`,
    `hourtv_live_page.dart`, `hourtv_startup_cover.dart`, `cast_proxy.dart`,
    `dlna_service.dart`, `epg_service.dart`, `iptv_server_service.dart`,
    `logo_image_provider.dart`, `update_service.dart`,
    `opensubtitles_repository.dart`, `dns_security_validator.dart`,
    `catalog_repository.dart`.
- **Windows:**
  - Hay toolchain (Visual Studio Build Tools 2022) y ya se registraron los
    plugins de Supabase para escritorio (commit `3463452`).
  - `video_player` **no tiene implementación para Windows**, así que hoy no
    reproduciría video.
  - `flutter_chrome_cast`, `unity_levelplay_mediation` y `webview_flutter` no
    tienen soporte en Windows.

---

## 4. Lo que hay que lograr

La misma HourTV en navegador y en computador:
- navegar el catálogo, buscar y ver fichas;
- reproducir películas, series y TV en vivo con subtítulos, reanudar y calidad;
- iniciar sesión y sincronizar con el teléfono;
- perfiles con control parental y perfil infantil;
- ajustes.

Todo con controles pensados para **mouse y teclado** (no táctil) y ventanas de
cualquier tamaño.

### Matriz de funciones esperada (confírmala o corrígela en tu plan)

| Función | Windows (escritorio) | Web (navegador) |
|---|---|---|
| Catálogo, búsqueda, fichas, perfiles, parental | Sí | Sí |
| Login y sync con Supabase | Sí | Sí (configurar URLs de redirección web en Supabase: es una tarea para Kleiner, avísale) |
| Base local Drift | Sí (nativa) | Sí, con Drift **web (WASM)** (`drift_flutter` ya está en dependencias; requiere `sqlite3.wasm` y el worker en `web/`) |
| Video HLS/MP4 directo | Sí, con `media_kit` (libmpv): soporta HLS, cabeceras HTTP y subtítulos | Sí para servidores con CORS; HLS en Chrome/Edge/Firefox requiere **hls.js** |
| Servidores embed con Referer (la mayoría del VOD) | Sí (`dart:io`: `EmbedResolver` + cabeceras en `media_kit`) | **No directo:** el navegador no puede leer esas páginas (CORS) ni enviar Referer. Ver §5.3 |
| Subtítulos del repo | Sí | Sí (`raw.githubusercontent.com` permite CORS) |
| Transmitir a TV | DLNA sí (mismo código, `dart:io` funciona en Windows); Chromecast no (ocultar) | No (ocultar el botón, o Cast SDK web solo si es simple; no es prioridad) |
| Anuncios | Pendiente de decisión de Kleiner (Unity no existe para escritorio) | Pendiente de decisión de Kleiner (red de anuncios web) |
| Actualizaciones | Descargar el `.zip`/instalador de Windows del release de GitHub | No aplica (la web se actualiza al desplegar) |
| PiP, orientación, servidor IPTV local | Ocultar lo que no aplique | Ocultar |

## 5. Enfoque técnico recomendado

### 5.1 Compilación multiplataforma
- Separa lo específico de plataforma con **imports condicionales**
  (`import 'x_io.dart' if (dart.library.js_interop) 'x_web.dart';`), nunca con
  `kIsWeb` alrededor de código que no compila en web.
- Drift:
  - Una sola función `openCatalogDatabase()` con implementación nativa (la
    actual) y web (`drift_flutter`, WASM).
  - Revisa que las pruebas que usan `CatalogDatabase.inMemory()` sigan
    funcionando.
- `StorageService`, caché de imágenes y `path_provider`: en web usa
  `shared_preferences` y caché del navegador. No escribas archivos.
- Todo servicio que use sockets (`dlna_service`, `cast_proxy`,
  `iptv_server_service`) queda disponible solo donde exista `dart:io`, y su UI
  se oculta en web.

### 5.2 Reproductor en escritorio
- Integra **`media_kit` + `media_kit_video`** solo para Windows (y macOS/Linux si
  aplica). Android sigue con `video_player` tal cual. No lo cambies.
- Pon una interfaz pequeña entre `PlayerScreen` y el motor para no duplicar la
  pantalla del reproductor. Ya existen `_VideoSelector` y la lógica de
  reanudar, subtítulos y calidad: reutilízalos.
- El reproductor debe soportar:
  - cabeceras de `EmbedResolver` (Referer/User-Agent);
  - subtítulos SRT/VTT, incluyendo el estilo de `SubtitleStyle`;
  - selección de variante HLS;
  - reanudar posición;
  - teclado: espacio = pausa, ←/→ = ±10 s, ↑/↓ = volumen, F / doble clic =
    pantalla completa, Esc = salir de pantalla completa, M = silencio;
  - mouse: controles que aparecen al mover y se ocultan solos.

### 5.3 Reproductor en web y el problema de los embeds
- Directo (sin proxy): `video_player_web` + hls.js para `.m3u8`, más MP4, para
  servidores que permiten CORS y no piden Referer.
- **Embeds y servidores con Referer no funcionan desde un navegador sin un
  servidor intermedio** que:
  1. resuelva la página embed;
  2. reenvíe la lista HLS y los segmentos con las cabeceras correctas y CORS.

  Eso cuesta ancho de banda y puede violar condiciones de uso de hostings
  gratuitos (por ejemplo, las de Cloudflare sobre servir video).
- **No elijas proveedor por tu cuenta.**
  - Implementa el cliente contra una URL de proxy configurable (vacía por
    defecto).
  - Cuando no haya proxy, muestra el mensaje honesto por servidor y ofrece los
    servidores que sí funcionan.
  - Escribe en tu reporte las opciones reales (dónde alojarlo, costo estimado,
    riesgos) para que Kleiner decida.

### 5.4 Interfaz para computador: estilo Netflix (decidido por Kleiner)

Kleiner vio el diseño actual de escritorio (el de TV, con menú lateral y
tarjetas horizontales) y **no le convence**. Eligió **estilo Netflix web**.
Esto aplica a **Windows y web con ancho de computador**. **La TV (Android TV)
se queda con su diseño actual**, pensado para control remoto; no lo toques.

**Qué no le gustó del diseño actual, para no repetirlo:**
- tarjetas horizontales con escenas en vez de los pósters verticales del
  celular;
- el destacado corta las caras y no tiene degradado;
- el logo queda reducido a "TV" en el menú colapsado;
- el reparto sale con círculos de iniciales, sin fotos;
- las filas no coinciden con las del celular ("HourTV Originals", "Series
  para ti");
- la ventana se titula "mi_app";
- Esc no cierra la ficha.

**Especificación:**
1. **Barra superior fija** (reemplaza el menú lateral en escritorio):
   - a la izquierda, el logo completo "Hour TV";
   - luego Inicio · Películas · Series · TV en vivo · Mi lista;
   - a la derecha, 🔍 buscar (se expande a un campo) y el avatar del perfil,
     con menú para cambiar perfil, Historial, Ajustes y Cuenta;
   - es transparente sobre el destacado y se vuelve negra al hacer scroll.
2. **Destacado (hero)** a todo el ancho, ~70 % del alto de la ventana:
   - imagen de fondo (`backdrop`) alineada para no cortar caras
     (`Alignment.topCenter`/`center` según proporción);
   - **degradado** negro desde la izquierda y desde abajo;
   - título grande, año · duración · ★, sinopsis de 2–3 líneas, botones
     **▶ Reproducir** (o "Continuar desde X" si hay avance, usando
     `resumeOfferFor`) y **Mi lista**;
   - usa los mismos 5 destacados del celular (`_quickFeatured`) y rota solo
     cada ~8 s, con puntos indicadores.
3. **Filas** con los **mismos datos y nombres que el celular**:
   - orden: Continuar viendo (con barra de progreso y "Quedan X min"),
     Recomendado para ti, Lo que más gusta, Películas, Series, Animes,
     K-Drama, Tendencia;
   - reutiliza las fuentes de datos de `hourtv_mobile_shell.dart`
     (`ContentStore`, `LikesService.rank`, recomendaciones); no inventes
     filas nuevas.
4. **Tarjetas = pósters verticales 2:3** (`logo`/poster, como en el celular):
   - cantidad por fila según el ancho (≈ 6–8 en 1366 px, más en pantallas
     grandes);
   - **hover:** agrandar un poco (escala ~1.08) con sombra y mostrar título,
     año y botón ▶;
   - cursor de mano;
   - **flechas ‹ ›** a los lados de cada fila al pasar el mouse, que avanzan
     una "página".
5. **Ficha** en escritorio:
   - fondo grande con degradado, póster a la izquierda y datos a la derecha
     (título, meta, sinopsis completa, género, reparto como texto o con fotos
     reales si TMDB las da; **nunca círculos con iniciales**);
   - botones Reproducir / Continuar, Mi lista, Me gusta y Transmitir (DLNA
     solo donde funcione);
   - en series, selector de temporada y episodios en lista con miniaturas;
   - Relacionados abajo, en fila de pósters;
   - **Esc o botón atrás del mouse** cierran la ficha.
6. **Buscar:** resultados en cuadrícula de pósters mientras se escribe.
7. **Mi lista / Historial / TV en vivo:** mismas pantallas de datos del
   celular, en cuadrícula de pósters (en vivo, en su lista actual con logos).
8. **Ventana (Windows):**
   - título **"HourTV"** e ícono de la app (hoy dice "mi_app");
   - tamaño mínimo ~1024×640;
   - recordar tamaño si es simple.
9. **Estilo visual:** mismos colores y tipografías que el celular
   (`HourTvMobileTokens`, verde `#00C781`, fondo negro), para que se sienta la
   misma marca.
10. **Web:** decide el layout por **ancho de ventana**: ≥ ~900 px → este diseño
    de escritorio; menos → el diseño del celular. No uses solo
    `kIsWeb → phone`.
11. No hay orientación ni `SystemChrome` en escritorio/web: protégelo.

Antes de programar, en la **Fase 0** entrega un boceto (captura o descripción
por pantalla) del Inicio, la ficha y el reproductor en 1366×768 y en 1920×1080,
para que Kleiner lo apruebe.

### 5.5 Anuncios en web y escritorio
- Kleiner exige anuncio obligatorio antes de películas y episodios (nunca en
  vivo).
- Unity LevelPlay solo existe en móvil.
- **Pregunta antes de integrar** cualquier red para web o escritorio.
- Mientras tanto, deja `AdService` con una implementación por plataforma que no
  muestre nada ni haga esperar al usuario. **Prohibido** mostrar un "espacio
  publicitario" vacío.

### 5.6 Distribución (solo tras aprobación)
- **Windows:**
  - `flutter build windows --release --dart-define-from-file=config/supabase.local.json`.
  - Empaqueta un `.zip` (o instalador si es simple y gratis) y súbelo **al mismo
    release de GitHub** como `HourTV-<versión>-windows.zip`.
  - Adapta `UpdateService` para que en Windows busque ese asset.
- **Web:**
  - `flutter build web --release --dart-define-from-file=...`.
  - Propón dónde alojarla (GitHub Pages o Vercel, donde ya está el panel) sin
    desplegar hasta que Kleiner apruebe.
  - Configura PWA básica (ícono, nombre, color) en `web/manifest.json`.

---

## 6. Plan por fases (entrega y verifica cada una antes de seguir)

**Fase 0: plan (no escribas código aún).**
- Confirma o corrige la matriz del §4.
- Lista los archivos que vas a tocar y las dependencias nuevas con su licencia.
- Estima el esfuerzo.
- Detalla lo que necesita decisión de Kleiner (proxy web, anuncios, hosting).
- Espera su visto bueno.

**Fase 1: compila y arranca.**
- `flutter build web` y `flutter build windows` compilan.
- La app abre, carga el catálogo, busca, abre fichas, cambia de perfil y aplica
  el control parental.
- Android intacto (pruebas y APK).

**Fase 2: reproducción en Windows.**
- `media_kit` con embeds, cabeceras, subtítulos, calidad, reanudar, teclado y
  pantalla completa.
- Prueba al menos:
  - una película embed (por ejemplo "Orgullo y prejuicio", servidor paulinito);
  - una serie;
  - un canal en vivo.

**Fase 3: reproducción en Web.**
- Directo con hls.js.
- Mensajes honestos para servidores que necesitan proxy.
- Cliente de proxy configurable, sin proxy activo.
- Prueba en Chrome y Edge.

**Fase 4: experiencia de computador (estilo Netflix, §5.4).**
- Barra superior, destacado con degradado, filas de pósters con hover y
  flechas, ficha nueva, Esc para volver, ventana "HourTV".
- Layout por ancho en web.
- Capturas en 1366×768 y 1920×1080 para Kleiner.
- Login y sincronización verificados entre Windows, web y el teléfono: marca
  favorito en uno y verifica que aparezca en otro.

**Fase 5: distribución.**
- Solo con aprobación: zip de Windows en el release, `UpdateService` de
  Windows y web desplegada.

## 7. Cómo reportar

Al final de cada fase, un reporte corto en español, sin jerga:
- **Qué funciona**, probado de verdad (con capturas si puedes).
- **Qué no funciona** y por qué.
- **Qué decisión necesitas de Kleiner.**
- Comandos para probarlo él mismo, por ejemplo
  `flutter run -d chrome --dart-define-from-file=config/supabase.local.json` o
  `flutter run -d windows ...`.
- Resultado de `flutter test`, `flutter analyze` y de los tres builds (APK, web,
  Windows).

Nunca digas que algo funciona si no lo probaste. Si algo quedó a medias, dilo.
