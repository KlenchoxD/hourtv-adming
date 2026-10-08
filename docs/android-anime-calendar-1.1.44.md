# Android 1.1.44 — calendario de anime y selector

## Alcance

- Calendario exclusivo de anime, accesible desde Perfil. Consulta semanal paginada de AniList, días en la zona horaria local, últimos estrenos de la semana y filtro En HourTV.
- Identificación por AniList ID o alias exactos y únicos; no se adivinan temporadas por coincidencias parciales. Se conservan `sourceUrl` y `anilistId` al cargar/guardar series.
- El horario de emisión no implica que ese episodio esté disponible en HourTV. Los enlaces abren la ficha del anime identificado, no un episodio supuesto.
- Caché de cuatro horas, hasta ocho semanas guardadas, aviso explícito de datos antiguos si falla la red y reintento cuando no existe caché válida.
- Consulta diferida: no añade solicitudes al arranque de Inicio. El estado de emisión solo aparece en la ficha de un anime identificado.
- Selector con encabezado fijo, lista desplazable, opciones numeradas, fila completa pulsable y estado Seleccionado. No cambia resolución de enlaces, tiempos de espera ni fallback automático de Tokianime.
- La altura de las cuadrículas reserva el espacio del texto independientemente del ancho del póster, evitando el desbordamiento de 2.1 px encontrado tras ampliar los títulos en 1.1.43.

## Verificación automatizada

- 8 pruebas nuevas aprobadas: paginación/caché/error/desduplicación/identidad y widgets de calendario/selector a 360x800 y 800x360.
- 18 pruebas dirigidas de Inicio, filtros de búsqueda y pantallas estrechas aprobadas después del ajuste de cuadrícula.
- Suite completa final: **627 aprobadas, 2 omitidas, 1 fallida**. No se presenta la suite como completamente verde.
- Fallo restante: `guest_migration_service_test.dart`, `GuestMigrationService inspection reports counts but does not expose content payloads`, línea 33: progreso esperado 3, obtenido 0. El servicio de migración, almacenamiento y su prueba son idénticos a HEAD anterior; quedan fuera del alcance de esta actualización.
- `dart format --output=none --set-exit-if-changed`: 13 archivos, cero cambios.
- `flutter analyze --no-pub` sobre los 13 archivos Dart de la actualización: sin problemas.

## Límites conocidos

- AniList proporciona el calendario original, no la disponibilidad del proveedor de vídeo. Las coincidencias ambiguas se muestran sin enlace al catálogo.
- Sin conexión solo se muestran semanas previamente guardadas. Los estados desconocidos no se etiquetan arbitrariamente como En emisión.
- El selector no corrige disponibilidad ni latencia de servidores externos; su selección y cambio automático permanecen intactos por solicitud del usuario.

## Validación de distribución

Compilación, firma, instalación, comprobación visual y publicación se registran en el informe de entrega de la versión.
