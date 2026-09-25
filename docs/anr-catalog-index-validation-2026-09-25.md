# Validación del índice asíncrono — 25 de septiembre de 2026

## Cambio

El commit previo `13d12d9` ya enviaba el índice compartido a `compute`, pero Buscar
lo reconstruía síncronamente cuando recibía `presentationIndex == null`, tanto en
`initState` como al cambiar el catálogo. Inicio también tenía un fallback síncrono.
Ahora esas rutas usan isolates. Buscar distingue un índice compartido pendiente,
muestra carga y ofrece reintento si falla su construcción local.

La entrega del índice actualiza las páginas mediante un notificador, conservando
el estado de búsqueda y scroll. Los resultados asíncronos obsoletos se descartan,
la caché incluye cambios en la lista de series y la consulta escrita durante la
carga se aplica al terminar.

## Pruebas

- Prueba real de `compute` con 4.000 canales y servidores anidados: ida/vuelta
  correcta; contador de construcción del isolate principal permanece en cero.
- Índice pendiente compartido: no hay fallback síncrono; conserva consulta escrita.
- Índice y pruebas asíncronas: 7/7.
- Búsqueda, filtros y pruebas asíncronas: 19/19.
- Comprobación ampliada de UI/historial/Inicio/Drift: 27 pasan y 4 fallan.
  Los cuatro fallos se reprodujeron también en el checkout base `0d93ef5`, sin
  estas modificaciones: dos expectativas antiguas de búsqueda en Drift y dos
  pruebas de apertura de películas/series desde Drift.
- Análisis de shell, nuevas pruebas y pruebas de filtros/rendimiento: sin problemas.

## Dispositivo físico

- Moto G24, ADB `ZT322M2PX5`, datos existentes preservados, instalación con `-r`.
- Antes: diálogo “HourTV no responde”. Android registró ANR a las 13:54:15,
  espera de 10.002 ms por un MotionEvent.
- APK profile compilada con `--dart-define-from-file=config/supabase.local.json`.
- Después: índice de 3.472 registros `_IndexedChannel` comprobado por VM Service
  en el isolate principal después de la transferencia. Es el conjunto visible
  deduplicado, no un catálogo de prueba pequeño.
- Seis ciclos Inicio/Buscar con 18 gestos de scroll. La UI respondió y el último
  ANR registrado siguió siendo el de las 13:54:15, anterior a la instalación.
- Evidencia local: `artifacts/anr-validation/before.png` y `validated.png`.
- SHA-256 APK instalada:
  `91AFC6B937DCF3371F38765B04DE33A85144B45D7BA0DBD99541A2C958EF95C1`.

## Límites de la validación

El arranque inicial aún tuvo demoras de sesión y red: restauración de sesión
5.950 ms, timeout de GitHub y posterior snapshot Supabase de 5.008.478 bytes.
No se declara un arranque instantáneo ni una garantía de cero jank.
`dumpsys gfxinfo` no se usa como prueba de FPS Flutter.

El control automático rechazó un comando posterior que agrupaba otro reinicio,
el cierre del perfilador y análisis de código, con motivo genérico “blocked by
policy”. No se completó esa repetición adicional del arranque. Cerrar y abrir
la app termina el perfilador temporal del proceso de diagnóstico.
