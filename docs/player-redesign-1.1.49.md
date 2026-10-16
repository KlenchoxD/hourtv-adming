# Rediseño del reproductor móvil — 1.1.49 (53)

Referencia aprobada: maqueta B, con pausa marfil, controles laterales sin
contenedores, tipografía sans serif, selector de servidor/idioma y barra inferior
compacta. Alcance: reproductor nativo móvil; no se reemplaza el motor de video.

## Implementación

- `hourtv_mobile_player_chrome.dart`: cabecera y barra de acciones de presentación,
  sin resolvedores ni controladores de video. En vertical, título y servidor se
  distribuyen en filas; las herramientas inferiores respetan el ancho disponible.
- `hourtv_playback_center.dart`: pausa/reproducción con superficie marfil e icono
  oscuro, saltos de 10 s transparentes y zonas de pulsación amplias.
- `PlayerChromeVisibility`: fundido de entrada 240 ms y salida 320 ms. Se ignoran
  pulsaciones y semántica al ocultarse. Al terminar el fundido se retiran los
  controles, evitando mantener sus selectores actualizándose fuera de pantalla.
- Corrección tras comparar la compilación 52 con la referencia: selector anclado
  al extremo derecho (regresión reproducida: terminaba en x673 en una vista de
  800 px; ahora en x784, respetando el margen de 16). Título y separación de
  controles centrales ajustados a las proporciones de la maqueta.
- El degradado cubre toda la pantalla, fuera del SafeArea, y comparte el mismo
  fundido que la cabecera y la barra. Antes se retiraba de golpe y dejaba una
  franja vertical junto al recorte de cámara: causa del corte visual reportado.
- Se usa una única animación de opacidad reversible por componente, en lugar de
  AnimatedSwitcher: los toques repetidos no crean copias superpuestas. Se respeta
  la preferencia de reducir animaciones del sistema.
- El buffering es independiente del estado de los controles: no se cruzan dos
  indicadores ni se deja pausa debajo de una rueda de carga. La superficie de
  video y el decoder no se animan ni se reconstruyen para cada tick del progreso.
- Durante buffering, los saltos también se desvanecen; el indicador sigue vivo
  en su propia capa de 76×76 sin reiniciarse ni aparecer sobre el botón de pausa.
- Audio/subtítulos, calidad, velocidad, PiP, aspecto, servidor y Cast llaman a las
  funciones nativas existentes. Se añadió selección de velocidad de 0.5× a 2×.
- `hourtv_player_surfaces.dart`: estilo común para diálogos y nuevo panel de
  opciones con filas, iconos y textos uniformes; «Mi lista» sustituye al corazón.
  La persistencia sigue usando el mecanismo existente de favoritos.
- `hourtv_cast_sheet.dart`: tipografía compartida, ancho máximo 560, cabecera y
  botón de cierre; se conservan descubrimiento, conexión y manejo de sesiones.
- No se cambian resolutores, cabeceras de streams, formatos, ADS ni transporte
  de red. Se conserva la corrección de VOE validada en la compilación 51.

## Verificación de código

- Análisis estático de cinco archivos de producción: No issues found.
- Pruebas de cabecera/barra a 320 y 800 px con texto ampliado.
- Pruebas de callbacks, accesibilidad de controles ocultos y transición real
  de opacidad antes de retirar widgets.
- Pruebas de panel de transmisión sin abrir conexiones externas.
- Pruebas de velocidad y Mi lista: modifican sus estados sin crear un segundo
  reproductor ni resolver de nuevo la fuente.
- Regresión de buffering, recuperación, servidor, Media3/mpv y TV en vivo:
  66 pruebas pasaron antes de la última ampliación de pruebas de los menús.
- Suite completa de la compilación 52: 753 correctas, 3 omitidas y 2 fallidas (exit 1).
  Los fallos siguen siendo migración de invitado y filtro de Series:
  `guest_migration_service_test.dart: inspection reports counts but does not
  expose content payloads` y `hourtv_mobile_search_filters_test.dart: filtro
  tipo Series muestra solamente series`. No se declara una suite verde.
- Regresión 53: se verifica que las cuatro capas (degradado, cabecera, centro y
  pie) están a opacidad 0.5 a mitad de salida, tanto por toque como por timeout,
  sin incrementar createCalls ni pauseCalls del reproductor.
- Ejecución dirigida final: 40/40 pruebas correctas (chrome, paneles, centro,
  buffering, TV en vivo sin pausa y recuperación de motor nativo).
- Suite completa repetida durante compilación 53: 755 correctas, 3 omitidas y
  3 fallidas. Además de los dos fallos anteriores, un umbral del benchmark de
  catálogo dio 63 ms contra un máximo de 50. Se repitió ese archivo después de
  terminar la compilación: 2/2 pruebas correctas. No se modificó ese benchmark.

## APK y comprobación física

Build normal: `flutter build apk --debug --target lib/main.dart
--build-name=1.1.49 --build-number=53`. El número es del artefacto de prueba,
no una publicación pública. Compilación 53 correcta (431 s), instalación -r
correcta en el Infinix 1402325559000585 y versión confirmada mediante dumpsys.
SHA256: 2F5157E6901D16A7E8638833906AC4CA3AB59E49ABA4AA7131CEC6D8C2D2A5FA.
APK guardado en outputs/android-webflux-2026-10-14 del workspace principal,
con nombre HourTV-1.1.49-53-player-fade-debug.apk. Nunca desinstalar HourTV ni usar
integration_test sobre el paquete del usuario.

Para mantener la pantalla despierta durante la prueba se cambió temporalmente
stay_on_while_plugged_in. Valor original 0; restaurado y confirmado en 0 al
terminar. Las escalas de animación del sistema siguen en 1.0, sin cambios.

Comprobación física final completada en el Infinix con autorización del usuario
para dejar HourTV al frente. Captura válida: `player-53-final-fade.mp4` y hoja
de fotogramas `player-53-final-contact.png`, en outputs/android-webflux-2026-10-14
del workspace principal. Se descartaron las primeras grabaciones interrumpidas.

- Selector alineado al extremo derecho y degradado continuo junto al recorte
  de cámara, comprobados en la captura `player-53-visible.png`.
- Ocultación por toque: en el video, 6.13 s todavía visible, 6.20 s parcialmente
  transparente, 6.27 s muy tenue y 6.33 s ya oculto.
- Ocultación por timeout: 12.13 s visible, 12.20 s parcialmente transparente,
  12.27 s muy tenue y 12.33 s oculto. Cabecera, centro, pie y degradado acompañan
  el mismo fundido; no aparece un corte separado del fondo.
- El contenido sigue avanzando durante ambos fundidos. La grabación final
  termina reproduciendo, sin pantalla negra ni reinicio en esos intervalos.
- Los toques rápidos/reversión y buffering se cubren además con pruebas de
  widgets. No se extrapola esta comprobación a un benchmark de FPS ni a todos
  los servidores o dispositivos. No fue necesario modificar ni reinstalar la
  compilación 53 para esta verificación.

## Pendientes fuera del rediseño

- Los dos fallos de pruebas generales citados arriba.
- Validación dinámica pendiente de MHDPlus y casos independientes FileMoon/Webflux.
- No se afirma un benchmark de FPS ni compatibilidad universal de hosts.
