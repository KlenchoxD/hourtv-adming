# Rediseño del panel de administración HourTV

Fecha: 2026-10-07. Estado: diseño visual B aprobado; especificación pendiente de revisión.

## Objetivo y alcance

Transformar el panel existente en un espacio de trabajo ordenado, con los colores de HourTV, separación entre acciones y edición, y menos elementos renderizados al desplazarse. Conservar las funciones actuales, los datos locales y el contrato del catálogo. No rediseñar la web pública, Android ni TV; no añadir servicios externos ni cambiar credenciales, permisos o esquema de base de datos.

Referencia visual aprobada: `C:/Users/Kleiner/.codex/generated_images/019f645e-2e2d-7c61-a5d3-583436ba4a78/exec-4ed16bba-81a1-4259-b7e1-caf4dc40ec7a.png`.

Corrección solicitada: **Catálogo · Pendientes · TV en vivo · Servidores debe estar centrado respecto al ancho del encabezado**, independientemente del ancho del logo y de los controles de cuenta. En pantallas estrechas el menú puede ocupar una fila propia, también centrada.

## Distribución

1. Encabezado: identidad HourTV a la izquierda, cuatro secciones centradas y acceso a la configuración/sesión existente a la derecha.
2. Cabecera de sección: título, resumen real del catálogo y acciones Añadir contenido / Publicar cambios. El indicador de cambios se calcula frente a la base remota guardada; no usar los números de ejemplo de la referencia.
3. Barra de herramientas independiente: Sincronizar tendencias, Descargar JSON, Importar JSON y Cargar de GitHub. Todas visibles y con acciones reales.
4. Franja de conexión: GitHub (configuración), repositorio configurado (enlace), rama, ruta del archivo, estado y acceso a copiar el enlace público. URL IPTV permanece accesible en TV en vivo.
5. Barra de filtros: buscador, tipo (Todos/Películas/Series), estado y contador real. Sin duplicar buscadores ni mezclar acciones de publicación con filtros.
6. Área principal: tabla paginada a la izquierda (aproximadamente 65%) e inspector del elemento seleccionado a la derecha (aproximadamente 35%). En móvil se apilan; las acciones continúan accesibles.
7. Pie discreto: atribución TMDB existente.

Paleta: negro, carbón, blanco/grises y acento verde esmeralda de HourTV. Sustituir los acentos rojos de la apariencia anterior, excepto mensajes semánticos de error/eliminación. Bordes finos, espacios regulares, iconos coherentes y foco de teclado visible; evitar efectos pesados y ornamentación redundante.

## Navegación y conservación de funciones

- Catálogo reúne películas y series; el filtro de tipo conserva ambas rutas de edición actuales. Cada fila lleva identidad estable y colección de origen, sin usar el índice de la lista filtrada como índice del catálogo.
- Pendientes sigue usando la regla existente: faltan año, género o rating. No reinterpretarlo como borradores no publicados.
- TV en vivo conserva fuentes M3U, Xtream y Stalker/MAG, editor, incorporación, eliminación y copia de URL IPTV. No modificar las credenciales de fuentes ni probar streams durante esta tarea.
- Servidores agrupa servidores caídos, páginas de respaldo y notificaciones mediante navegación secundaria. Conserva filtros, acciones individuales/lotes, revalidación, recuperación de publicación y requisitos de sesión existentes.
- GitHub abre el formulario actual. Cargar reutiliza la carga remota y actualización de base. Descargar e importar reutilizan el formato actual del catálogo.
- Sincronizar tendencias conserva la consulta TMDB y su selección/confirmación actual. No sincronizar automáticamente al abrir el panel.
- Publicar conserva la combinación de tres vías, los IDs eliminados y la protección ante cambios concurrentes del scraper; mantiene la sincronización de snapshot y los avisos existentes.
- Autocompletado TMDB, fotografías del reparto, subida de imágenes, temporadas/episodios, idiomas/servidores, miniaturas de episodios y temporadas especiales (0) continúan en el editor.

## Tabla e inspector

La tabla muestra una miniatura pequeña, título/año, tipo, información de completitud y cambios locales, y acciones. Solo mostrar fechas si existen en los datos; no inventar una columna de actualización con fechas ficticias. Los estados de publicación derivados de la base deben distinguirse de la completitud de metadatos.

Seleccionar una fila actualiza el inspector sin abrir inmediatamente el editor. El inspector muestra fondo/caratula, datos principales y secciones plegables de temporadas/episodios, servidores e información avanzada. **Abrir editor** lleva al formulario actual del elemento, donde se guardan los cambios. Esta separación evita dos formularios incompatibles editando simultáneamente el mismo objeto. Los campos mostrados en el inspector son de consulta y se identifican como tales.

Añadir contenido abre el editor con un tipo explícito cuando el filtro sea Todos. Guardar conserva la selección por ID si el elemento cambia de colección. Eliminar conserva la confirmación y publicación actuales; la selección posterior no puede apuntar a un elemento eliminado.

## Rendimiento y estado de interfaz

El render actual monta todas las tarjetas mediante `items.map(...).join('')` y busca su índice original por cada tarjeta. Esto justifica limitar el DOM; no equivale a haber medido todavía la causa completa del lag.

- Paginación de 25 filas por defecto, con tamaños 25/50/100 y un máximo de 100 filas montadas en las listas del nuevo espacio de trabajo.
- Filtrado con demora breve (150 ms) para no reconstruir el listado en cada tecla inmediata; resultados y navegación por teclado siguen disponibles.
- Reiniciar la página al cambiar filtros; ajustar una página que quede vacía tras eliminar/importar/cargar. Los contadores reflejan el conjunto filtrado, no solo la página visible.
- Miniaturas pequeñas con carga diferida, dimensiones reservadas y fallback ante fallo. El inspector carga imágenes solo para el elemento seleccionado.
- Mantener filtros, selección y página durante operaciones que no cambian la sección. No recrear el inspector completo cuando solo cambia un aviso de conexión.
- No introducir blur grande fijo, animaciones por fila ni sombras costosas durante scroll. Respetar movimiento reducido.
- Reutilizar los límites de las listas de salud ya existentes; no introducir cambios al backend por motivos estéticos.

## Estados y errores

El estado de GitHub será Sin configurar / Configurado, sin comprobar / Comprobando / Última operación correcta / Error. Configurar propietario y repo no demuestra una conexión correcta. Un error conserva los datos y proporciona un mensaje útil sin exponer tokens.

El indicador de cambios se basa en diferencias de contenido frente a la base persistida, incluyendo altas, modificaciones y eliminaciones. Si aún no existe base confiable, mostrar Base remota no cargada, no afirmar que todo está publicado. Tras publicar se usa la base realmente confirmada; si hubo edición mientras se publicaba, esos cambios siguen pendientes.

Carga, tendencias y publicación muestran progreso y evitan dobles envíos. Respetar las confirmaciones existentes; antes de una carga que sustituya cambios locales, advertir al usuario. Los errores de imagen no destruyen datos, y los avisos de sincronización parcial se conservan.

## Límites técnicos

Mantener los módulos de publicación, autenticación, reemplazos y TMDB existentes. Extraer la lógica de selección/filtros/paginación y diferencia visual a un módulo pequeño probado, y estilos del espacio de trabajo a un archivo dedicado si ayuda a reducir el HTML monolítico. No rehacer APIs ni sustituir librerías como parte del rediseño.

Los cambios no deben guardar passwords/tokens en registros ni fixtures. La documentación y los tests usan datos inventados. Preservar los cambios ajenos ya presentes en el worktree.

## Verificación y publicación

- Tests de paginación, filtros, selección estable, cambios frente a la base y combinación catálogo/películas/series.
- Tests de enlace entre cada botón visible y su función actual; ninguna acción decorativa.
- Regresión del editor: miniaturas TMDB distintas por episodio, valores nulos para imágenes faltantes, temporada 0, idiomas y servidores.
- Regresión de publicación y carga: no perder servidores añadidos por el scraper, no restaurar elementos eliminados, no marcar cambios concurrentes como publicados.
- Comprobar escritorio (1440 y 1366 px), tablet y móvil; menú realmente centrado, textos sin recortar, desplazamiento horizontal solo donde sea necesario, teclado y movimiento reducido.
- Verificar número acotado de filas con un catálogo grande y comparar el comportamiento del scroll si hay navegador disponible. Si no se puede inspeccionar visualmente, informar de la limitación, no declarar esa prueba realizada.
- Ejecutar suites relevantes y la suite completa; separar fallos previos de regresiones. Revisión de código antes de publicar.
- Desplegar únicamente en el proyecto Vercel real `hourtv-adming` y comprobar el despliegue antes de promoverlo a `https://hourtv-adming.vercel.app`. No crear un proyecto auxiliar.

## Criterio de aceptación

La distribución coincide con la referencia B corregida, el menú principal está centrado, todos los controles solicitados siguen funcionando, los datos se preservan, el listado tiene DOM acotado y ningún estado/cifra de ejemplo se presenta como real. No publicar un cambio meramente visual con funciones rotas.
