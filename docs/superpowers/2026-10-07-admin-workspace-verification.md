# Verificación del rediseño del panel HourTV

## Resultado de implementación

Menú principal centrado: Catálogo, Pendientes, TV en vivo y Servidores. Utilidades separadas de filtros: sincronizar tendencias, descargar/importar JSON, cargar de GitHub y configuración GitHub. Repositorio, rama, archivo y estado visibles. Tabla paginada e inspector de consulta conectados al editor original; se mantienen autenticación, recuperación y flujos de servidores existentes.

## Pruebas

- Suite completa: 212 pruebas, 210 correctas, 2 fallos preexistentes, ninguna omitida. Cero fallos nuevos.
- Los dos fallos previos son `individual rejects missing high confidence, unsafe URL, or declined confirmation before RPC` y `apply and discard use one atomic RPC each`, en `replacement-admin-actions.test.js`. Ambos esperan un candidato que ahora requiere revalidación. No se modificó incidentalmente ese contrato.
- Revisión independiente: cinco hallazgos críticos/importantes corregidos. Nueve casos nuevos fallaron antes de las correcciones y pasaron después. Suite enfocada: 24/24.
- Pruebas del navegador real en Chrome aislado, con catálogo y red simulados: importación/exportación, editor, utilidades, notificaciones, carga/publicación concurrentes, filtros, selección e identidad.
- Resoluciones 1440, 1366, 768 y 390 px: navegación geométricamente centrada y sin desbordamiento de página.
- Catálogo sintético de 10000 títulos: pico inicial de 25 filas, máximo permitido 100. En medición local aislada, separación media entre frames 16,68 ms y máxima 17,60 ms. No representa una garantía de rendimiento en otros dispositivos o redes.

## Decisiones y límites

1. Se verificó el baseline antes de implementar para distinguir regresiones de deuda previa. Los dos fallos existentes se conservaron conforme al plan aprobado.
2. Se reutilizó el worktree aislado existente; no se incluyeron modificaciones ajenas de Flutter/web ni se integró la rama automáticamente.
3. Layout y comportamiento se probaron en el documento real mediante Chrome headless, no por coincidencias de texto CSS. El runtime opcional del navegador es necesario para repetir esas pruebas.
4. Se preservaron rutas secundarias de servidores mediante `setSection`/`setTab`, incluyendo la apertura real de una notificación y sus detalles.
5. Cargas/publicaciones se vinculan a la configuración capturada. Cambiar de repositorio durante una operación requiere repetirla en el contexto actual; no se mezclan los datos.
6. La base de comparación utiliza contexto y huella SHA-256 en metadatos auxiliares, sin cambiar `catalog.json`. Bases antiguas no verificadas muestran comparación desconocida hasta cargar/publicar, manteniendo el merge previo dentro de su contexto original.
7. Eliminaciones con ID ausente o repetido se bloquean con un mensaje de corrección del JSON. No se inventan IDs ni se cambia el algoritmo de merge. Un ID numérico cero es válido.
8. No se ampliaron las reglas de importación de documentos malformados fuera del contrato aprobado de campos opcionales; se conserva la validación original.
9. No se modificaron esquemas, permisos ni APIs Supabase. Las pruebas de autenticación/red fueron aisladas; no se afirma una verificación destructiva contra el catálogo ni la base de datos reales.

## Detalle menor pendiente

En el inspector de consulta, un rating válido de `0` se visualiza como un guion. El dato almacenado y su edición se conservan. Se pospuso al no formar parte de los hallazgos críticos/importantes de esta pasada.

## Publicación

Publicado y promovido el 7 de octubre de 2026 en `https://hourtv-adming.vercel.app`.

- Proyecto verificado: `hourtv-adming`, raíz `admin`, Node 24, framework Other.
- Código del producto: commit `311bef51b3e9d9f0591ae5e40be699e7f7483637`.
- Despliegue: `dpl_7TMDA6xCem3g6aRCYuNUt2mk5DAA`, estado READY, producción.
- URL inmutable: `https://hourtv-adming-ip37n8yib-kleinermadridmaceas123-2371s-projects.vercel.app`.
- HTML y cinco archivos CSS/JS comparados con el código local antes y después de promover: coincidencia exacta normalizando saltos de línea.
- Endpoint público TMDB para temporada 1 del ID 1399: respuesta correcta con 10 episodios, tanto en el despliegue como en el alias final.
- Revisión acotada de registros de error (15 minutos): un aviso Node `DEP0169` sobre `url.parse()`, con respuesta HTTP 200. Sin fallo funcional observado en esa comprobación. No se configuraron drains ni nueva monitorización; su configuración no se auditó en este cambio.
- Se siguió el procedimiento de Vercel: comprobar destino, crear producción sin dominio, verificar y promover exactamente ese despliegue. No se creó un proyecto adicional.

## Corrección posterior: selectores y espaciado

Petición del usuario: flechas bien contenidas, menú desplegable coherente con el panel y separación entre «Filas» y su campo. Se añadió un componente de selector reutilizable para Tipo, Estado y Filas, sin cambiar el modelo de datos ni el comportamiento de filtrado/paginación. Los controles originales siguen como puente para los eventos existentes, pero no duplican el foco ni la exposición accesible.

- Flecha SVG centrada y con margen interior; menú oscuro con selección esmeralda; etiqueta «Filas» separada 12 px.
- Acceso por teclado, Escape, Tab, búsqueda por inicial, foco restituido tras paginar, clic fuera para cerrar, apertura hacia arriba cerca del borde inferior y cierre al redimensionar.
- Cinco pruebas nuevas de navegador correctas. Regresión completa: 217 pruebas, 215 correctas y los mismos dos fallos previos; cero omisiones y cero fallos nuevos.
- Inspección visual con datos sintéticos y comprobaciones geométricas a 1440/390 px. Se mantienen las pruebas responsive previas a 1366/768 px.
- Assets versionados con `v=20261007-selects` para no reutilizar el CSS/JS anterior en caché al recargar.
- Commit del producto: `ac7fc08`. Vercel producción READY, framework Other, build 1 s. Despliegue `dpl_6qdun3o8FmbZHHb1cB5YqWLW7pAj` promovido al alias habitual.
- Cuatro archivos comparados antes/después de promoción: coincidencia exacta. Prueba adicional sobre el dominio de producción con Chrome aislado y catálogo sintético: apertura de menú, selección de Series, cierre y filtro correctos. No se tocó el catálogo real ni se ejecutaron escrituras remotas de prueba.
