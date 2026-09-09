# HourTV: catálogo escalable, sincronización y rendimiento con Supabase

Fecha: 2026-09-09

## Objetivo

Preparar HourTV para un catálogo grande alimentado por ServerHunter sin degradar la fluidez, y añadir cuentas reales con hasta cinco perfiles sincronizados. Supabase será la fuente principal del catálogo y del estado de usuario; `catalog.json` permanecerá temporalmente como respaldo durante una migración gradual.

Esta fase incluye recomendaciones personalizadas por perfil basadas en favoritos,
progreso y géneros consumidos. No incluye analítica comercial, perfiles
publicitarios ni estadísticas agregadas de usuarios.

## Problemas confirmados

- `ContentStore.load()` marca la carga como terminada al restaurar cualquier caché o fuente local, aunque el catálogo remoto continúa actualizándose en segundo plano. La pantalla principal puede aparecer incompleta.
- Inicio selecciona el hero con `movies.take(5)` y no prioriza títulos realmente destacados.
- Buscar normaliza, filtra y ordena el catálogo repetidamente durante reconstrucciones visuales.
- El shell mantiene páginas pesadas construidas dentro de un `IndexedStack`, aunque aún no se hayan visitado.
- “Continuar viendo” usa tarjetas horizontales grandes que no coinciden con las tarjetas del catálogo.
- Las búsquedas recientes se muestran como chips horizontales rígidos.
- Los perfiles actuales son locales; no representan una identidad recuperable ni sincronizan entre dispositivos.
- Un único archivo JSON dejará de ser adecuado cuando el catálogo crezca a miles o decenas de miles de títulos.

Supabase no sustituye las optimizaciones de Flutter: resuelve crecimiento, consulta remota y sincronización. La aplicación también debe eliminar cálculos repetidos, reconstrucciones globales y cargas visuales prematuras.

## Alcance

### Incluido

- Registro e inicio de sesión mediante correo y contraseña.
- Confirmación de correo y recuperación de contraseña.
- Modo Invitado local sin sincronización.
- Hasta cinco perfiles por cuenta.
- Favoritos y progreso independientes por perfil.
- Sincronización offline-first entre dispositivos.
- Importación única de datos del modo Invitado.
- Recomendaciones personalizadas por perfil.
- Catálogo Supabase paginado con búsqueda, tipo y género.
- Películas, series, temporadas, episodios, servidores e idiomas.
- Caché local indexada.
- Escritura dual Supabase + `catalog.json` durante la transición.
- Fallback al JSON o a la última caché válida.
- Carga inicial coordinada, hero correcto, páginas diferidas y rediseños aprobados.

### Excluido

- Inicio de sesión con Google en esta fase.
- Estadísticas agregadas, telemetría comercial o historial de búsquedas remoto.
- Seguimiento publicitario, venta de datos o perfiles compartidos entre cuentas.
- Eliminación inmediata de `catalog.json`.
- Cambios a la versión pública `v1.1.14` durante desarrollo.
- Claves administrativas dentro de HourTV o ServerHunter distribuido.

## Arquitectura general

```text
ServerHunter / Panel administrativo
             |
             v
      Backend administrativo
        |             |
        v             v
   Supabase       catalog.json
   (principal)    (transición)
        |
        v
      HourTV <--> caché local indexada
        |
        +--> fallback JSON si Supabase no está disponible
```

El backend administrativo es la única ruta de escritura privilegiada. HourTV usa una clave pública de cliente y políticas RLS. ServerHunter distribuido no recibe `service_role` ni secretos equivalentes.

## Modelo de datos

### Identidad y perfiles

- `auth.users`: identidad gestionada por Supabase Auth.
- `profiles`: `id`, `account_id`, nombre, avatar, indicador infantil opcional, fechas.
- Cada cuenta puede poseer como máximo cinco perfiles. El límite se aplica en la base de datos además de la interfaz.
- Un perfil solo puede ser leído o modificado por la cuenta propietaria.

### Catálogo

- `titles`: identidad estable, tipo película/serie, IDs externos, título, título original, año, sinopsis, duración, clasificación numérica existente, póster, backdrop, estado publicado y marca destacada.
- `genres`: catálogo normalizado de géneros.
- `title_genres`: relación muchos-a-muchos.
- `seasons`: serie, número y metadatos de temporada.
- `episodes`: temporada, número, título, sinopsis, imágenes y metadatos.
- `languages`: código y nombre normalizados.
- `sources`: origen reproducible asociado a una película o episodio, servidor, idioma, URL pública admitida, orden, verificación y estado.

Las restricciones únicas deben impedir duplicados por identidad externa o identidad normalizada y preservar varios servidores e idiomas legítimos para el mismo contenido.

### Estado por perfil

- `favorites`: perfil, título y fecha.
- `playback_progress`: perfil, título o episodio, posición, duración, estado terminado y `updated_at`.
- `recommendation_preferences`: afinidad derivada por perfil y género, con
  puntuación y fecha de actualización; nunca contiene búsquedas, credenciales ni
  información de otras cuentas.
- `guest_migrations`: cuenta/perfil, identificador idempotente y fecha de importación.

No se almacenan contraseñas en tablas propias, cookies, tokens de reproducción, licencias DRM ni rutas internas sensibles.

## Autenticación

- La primera fase admite correo y contraseña.
- El correo debe confirmarse antes de sincronizar perfiles, favoritos o progreso.
- La recuperación de contraseña usa el flujo oficial de Supabase Auth.
- La sesión se persiste de manera segura y se renueva mediante el SDK.
- Si existe una sesión válida pero no hay red, la aplicación puede abrir con caché local.
- El modo Invitado permanece disponible sin cuenta.
- Google podrá añadirse posteriormente sobre la misma identidad sin modificar las tablas de perfiles.

## Migración desde Invitado

Al iniciar sesión por primera vez, HourTV ofrece importar favoritos y progreso locales a un perfil seleccionado. Antes de confirmar muestra cantidades. La operación usa una clave idempotente para que un reintento no duplique datos. Los datos locales solo se eliminan si el backend confirma la importación completa; si falla, permanecen disponibles.

## Seguridad y RLS

- RLS se activa en todas las tablas expuestas.
- El catálogo publicado admite lectura para `anon` y `authenticated`, permitiendo el modo Invitado.
- Perfiles, favoritos, progreso y migraciones requieren usuario autenticado y una condición de propiedad por `auth.uid()`.
- Las políticas de actualización incluyen `USING` y `WITH CHECK`.
- Las vistas expuestas, si se necesitan, usan `security_invoker`.
- Ninguna clave `service_role` se incluye en Flutter, ServerHunter distribuido ni repositorios públicos.
- Las escrituras administrativas pasan por un entorno backend protegido.
- La eliminación de cuenta requiere confirmación y una operación backend controlada.

## Lectura del catálogo y paginación

HourTV solicita solo los datos necesarios:

- Inicio: destacados y páginas pequeñas para cada sección.
- Buscar: consulta por texto, tipo y género.
- Series: cabecera primero; temporadas y episodios bajo demanda.
- Servidores: se cargan al abrir el detalle o reproducir.

La paginación debe ser estable mediante un cursor basado en orden e identidad, evitando descargar el catálogo completo y evitando que inserciones nuevas desplacen páginas ya vistas. Al acercarse al final del scroll se precarga la página siguiente. Una consulta anterior se cancela o ignora cuando el usuario sigue escribiendo.

## Caché local y sincronización

El catálogo grande deja de almacenarse como un JSON monolítico en `SharedPreferences`. Se utiliza una base local indexada compatible con Flutter para páginas, metadatos y relaciones necesarias. `SharedPreferences` queda reservado para preferencias pequeñas.

La lectura es offline-first:

1. Mostrar caché válida.
2. Solicitar cambios remotos.
3. Actualizar filas afectadas.
4. Notificar únicamente a las vistas cuyos datos cambiaron.

Favoritos y progreso se escriben primero localmente y se agregan a una cola de sincronización. En conflictos entre dispositivos gana el registro con `updated_at` más reciente. Un progreso de aproximadamente 95 % o superior se considera terminado y deja de aparecer en “Continuar viendo”.

## Recomendaciones personalizadas

La fila “Recomendado para ti” se calcula de forma independiente para cada
perfil. La primera versión usa reglas comprensibles, no un modelo opaco:

- Un favorito aporta una señal fuerte a los géneros del título.
- Una reproducción con progreso significativo aporta una señal moderada.
- Un título terminado aporta una señal mayor que una apertura accidental.
- Una eliminación de favoritos no se interpreta como preferencia negativa.
- Los títulos ya terminados se excluyen salvo que formen parte de una saga o
  exista una temporada posterior pertinente.
- El resultado mezcla los géneros preferidos para evitar una fila compuesta por
  un único género.

Para cuentas verificadas, las afinidades se sincronizan con Supabase y son
idénticas entre dispositivos. En modo Invitado se calculan solamente en el
teléfono y no se envía actividad. La aplicación no almacena búsquedas para este
fin, no compara perfiles entre cuentas y no comparte señales con publicidad.

Cuando un perfil no tiene actividad suficiente se muestran destacados reales y
contenido popular editorial como estado de arranque, identificado como tal. El
cálculo se actualiza fuera de la ruta crítica de apertura y nunca bloquea Inicio.

## Estado de carga inicial

La aplicación presenta una tapadera única con fases reales:

1. Preparando aplicación.
2. Restaurando sesión.
3. Abriendo caché local.
4. Sincronizando catálogo inicial.
5. Construyendo Inicio.
6. Listo.

Con caché válida, el arranque puede continuar rápidamente y revalidar en segundo plano. En una primera instalación se espera la primera página real. Toda espera de red tiene límite; si falla, se usa `catalog.json` o la última caché válida y se muestra un aviso recuperable. TMDB, IPTV y enriquecimientos secundarios no bloquean el acceso.

La tapadera no desaparece hasta que Inicio tenga un estado consistente: contenido real, fallback válido o error accionable. No debe existir un intervalo en el que la barra termine y el catálogo continúe vacío.

## Rendimiento de Flutter

- Inicio, Buscar, TV, Biblioteca y Perfil se crean de forma diferida al visitarse.
- El índice local conserva título normalizado, tipo, géneros, año y estado destacado; no se recalcula dentro de `build()`.
- Las listas usan constructores perezosos y claves estables.
- Las imágenes solicitan dimensiones acordes al dispositivo y usan caché.
- Los cambios de progreso actualizan el elemento afectado, no todo el shell.
- Las recomendaciones se recalculan incrementalmente cuando cambian favoritos o
  progreso, nunca durante cada `build()`.
- Buscar aplica debounce y consulta paginada.
- Las respuestas obsoletas se descartan mediante identificador de consulta o cancelación.
- Se instrumentan tiempos de arranque, búsqueda y construcción para pruebas locales, sin enviar telemetría.

## Hero, búsquedas recientes y Continuar viendo

### Hero

El hero prioriza contenido publicado con `isFeatured=true`, backdrop horizontal válido y al menos una fuente reproducible. El orden editorial proviene del backend. Si no existen suficientes destacados, se usa un respaldo determinista con contenido completo; nunca `movies.take(5)` arbitrariamente.

### Búsquedas recientes

El historial permanece local al perfil/dispositivo y no se usa para estadísticas. Se muestra como una sección compacta con icono, texto y acción para borrar. Desaparece cuando el usuario comienza a escribir. No usa chips horizontales rígidos.

### Continuar viendo

Reutiliza la proporción, dimensiones y lenguaje visual de las tarjetas verticales del catálogo. Añade únicamente una barra fina de progreso y tiempo restante cuando exista información real. Conserva reanudación directa y separación por perfil.

## Publicación desde ServerHunter y el panel

ServerHunter entrega resultados al backend administrativo. El backend valida identidad y metadatos, deduplica y realiza una transacción:

- Si el título no existe, lo crea con sus relaciones.
- Si existe, añade o actualiza servidores sin duplicar el título.
- En series, actualiza temporadas y episodios mediante identidades estables.
- Los resultados incompletos permanecen en Pendientes.
- Durante la transición, tras una escritura correcta en Supabase se regenera o actualiza `catalog.json`.

Un fallo al actualizar el JSON no revierte una transacción ya confirmada en Supabase; se registra como trabajo de reparación. Un fallo en Supabase impide marcar la publicación como completa.

## Estrategia de migración

1. Crear un proyecto de desarrollo y aplicar esquema, índices y RLS.
2. Importar el catálogo actual de forma idempotente.
3. Comparar conteos y muestras de películas, series, temporadas, episodios, idiomas y servidores.
4. Activar escritura dual en backend/panel.
5. Incorporar repositorio Supabase y caché local en HourTV detrás de una configuración remota.
6. Probar una APK interna sin sustituir `v1.1.14`.
7. Activar Supabase gradualmente y supervisar fallbacks localmente.
8. Retirar la dependencia primaria del JSON cuando las comparaciones sean estables. El momento de eliminar el fallback requiere una decisión posterior.

## Manejo de errores

- Sin red: caché local y cola de sincronización.
- Supabase no disponible: fallback JSON o caché, con reintento manual.
- Sesión expirada: intentar renovar; si falla, conservar datos locales y solicitar autenticación sin borrarlos.
- Conflicto de progreso: gana el `updated_at` más reciente.
- Publicación parcial: estado Pendiente con causa visible.
- Página remota obsoleta: descartar la respuesta si ya existe una consulta más reciente.
- Caché dañada: reconstruir desde Supabase o JSON sin afectar credenciales.

## Pruebas y criterios de aceptación

- Registro, confirmación de correo, inicio, cierre y recuperación de contraseña.
- Máximo cinco perfiles; el sexto se rechaza también en base de datos.
- RLS impide acceso cruzado entre cuentas y perfiles.
- Invitado funciona sin cuenta y con conexión inestable.
- Importación de Invitado es confirmada, idempotente y no destructiva ante fallos.
- Favoritos y progreso sincronizan entre dos dispositivos simulados.
- Las recomendaciones son independientes por perfil, responden a favoritos y
  progreso, excluyen contenido terminado y no usan búsquedas.
- Invitado obtiene recomendaciones locales sin enviar actividad.
- El 95 % marca terminado y actualiza “Continuar viendo”.
- Catálogo, búsqueda, tipo y género funcionan con paginación estable.
- Hero contiene destacados reales y nunca selecciona elementos arbitrarios si existen destacados válidos.
- Series conservan temporadas, episodios, idiomas y servidores.
- Caída de Supabase activa fallback sin pantalla vacía.
- La tapadera de carga permanece hasta alcanzar contenido, fallback o error accionable.
- Un catálogo grande generado para pruebas mantiene búsqueda y scroll fluidos.
- “Continuar viendo” usa tarjetas equivalentes a las demás filas.
- Actualizar desde HourTV 1.1.14 conserva preferencias, Invitado, favoritos y progreso local.
- La APK interna se prueba físicamente antes de un release público.

## Despliegue y reversión

La implementación usa un proyecto y una APK de prueba. `v1.1.14` no se modifica. La lectura desde Supabase se habilita mediante configuración remota; desactivarla devuelve HourTV al JSON/caché sin reinstalar. La escritura dual permite reconstruir diferencias durante la transición. Ningún release público se crea hasta completar pruebas de migración, seguridad, rendimiento y dispositivo físico.

## Decisiones aprobadas

- Supabase se incorpora ahora por crecimiento y sincronización, no como parche aislado de rendimiento.
- Autenticación inicial: correo y contraseña.
- Confirmación de correo: obligatoria.
- Hasta cinco perfiles por cuenta.
- Modo Invitado: conservado.
- Importación de Invitado: disponible y confirmada.
- Migración: gradual con escritura dual.
- Catálogo: Supabase principal con caché local y fallback JSON temporal.
- Recomendaciones personalizadas: incluidas por perfil usando favoritos,
  progreso y géneros consumidos.
- Estadísticas agregadas y seguimiento publicitario: excluidos.
