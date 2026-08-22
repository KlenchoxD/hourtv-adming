# HourTV Android — Perfiles persistentes y catálogo progresivo

Fecha: 2026-08-22  
Estado: dirección visual y funcional aprobada

## Objetivo

Mejorar el prototipo Android actual de HourTV con dos capacidades independientes:

1. Perfiles creados y administrados por el usuario, con selección obligatoria al iniciar.
2. Exploración progresiva del catálogo completo dentro de Buscar, sin rediseñar la interfaz existente.

La implementación debe conservar la identidad actual de HourTV, las rutas aprobadas y los componentes visuales existentes. Los dos bloques se implementarán y verificarán por separado para reducir regresiones.

## Alcance protegido

- No rediseñar Inicio.
- No cambiar la estructura visual superior de Buscar, sus búsquedas recientes ni sus tendencias.
- No duplicar tarjetas, perfiles ni fuentes de datos.
- No introducir imágenes remotas inestables.
- No cambiar las funciones actuales de reproducción, TV, detalles o biblioteca.
- No mostrar Header ni Bottom Navigation durante la selección o creación inicial de perfiles.

## 1. Perfiles de usuario

### Flujo de primera ejecución

Si no existen perfiles guardados, HourTV mostrará directamente una vista de creación de perfil. El usuario no podrá entrar a Inicio hasta crear uno.

La creación incluirá:

- Nombre obligatorio, con espacios recortados y un máximo de 20 caracteres.
- Selección obligatoria de un avatar HourTV.
- Opción de perfil infantil.
- Acción principal `Crear perfil`, deshabilitada mientras falte un dato obligatorio.

Cuando se cree el primer perfil, este se guardará, se establecerá como perfil activo y se abrirá Inicio. En las aperturas posteriores se mostrará siempre `¿Quién está viendo?` antes de entrar a la aplicación.

### Selector de perfiles

El selector reutilizará el lenguaje visual aprobado:

- Fondo `#050505`.
- Logo HourTV existente.
- Texto principal blanco y secundario gris.
- Verde HourTV como acento de interacción.
- Sin Header, categorías o barra inferior.
- Ningún perfil preseleccionado.
- Objetivos táctiles de al menos 48 px.

Cada perfil mostrará su avatar y nombre. El selector admitirá un máximo de cinco perfiles y añadirá:

- `Añadir perfil` mientras no se alcance el límite.
- `Administrar perfiles` para editar o eliminar perfiles.

No se podrá eliminar el último perfil existente sin crear otro primero. Si se elimina el perfil activo, HourTV volverá al selector.

### Avatares

HourTV tendrá una galería local de avatares prediseñados. No se permitirá subir fotografías personales en esta fase; así se evitan permisos, recorte, compresión, almacenamiento y dependencias externas.

La galería deberá:

- Contener opciones visualmente distintas y coherentes con HourTV.
- Mostrar la selección mediante un borde verde discreto y una marca pequeña.
- Mantener una proporción cuadrada y un recorte consistente.
- Permitir reemplazar o ampliar la colección sin cambiar el modelo de perfiles.

### Persistencia

Los perfiles se almacenarán localmente con una clave versionada, por ejemplo `hourtv.profiles.v1`. El perfil elegido se mantendrá solo durante la sesión activa; una nueva carga completa volverá a mostrar el selector.

Modelo mínimo:

```ts
interface StoredProfile {
  id: string;
  name: string;
  avatarId: string;
  isKidsProfile: boolean;
  createdAt: number;
}
```

Los ajustes internos requeridos por el `UserProfile` actual se derivarán de una plantilla existente al activar el perfil. No se duplicarán configuraciones completas dentro del almacenamiento.

Si el almacenamiento está corrupto o no puede leerse, HourTV volverá de forma segura a la creación del primer perfil sin bloquear la aplicación.

## 2. Catálogo progresivo en Buscar

### Ubicación

Inicio seguirá siendo una superficie editorial de recomendaciones. El catálogo completo se mostrará dentro de Buscar, debajo de las secciones actuales cuando no haya una consulta activa.

La estructura existente de Buscar se conserva:

1. Campo de búsqueda.
2. Búsquedas recientes.
3. Tendencias.
4. Nueva sección `Explorar catálogo`.

### Carga progresiva

`Explorar catálogo` utilizará las tarjetas existentes y mostrará películas, series, novelas, anime y cualquier otro contenido recibido en `mediaItems`.

Comportamiento:

- Primera carga: 9 títulos.
- Siguientes cargas: lotes de 6 títulos.
- Un observador al final de la cuadrícula solicitará el siguiente lote al acercarse al borde.
- No se duplicarán títulos ni se repetirá el catálogo para simular infinitud.
- Al agotarse el catálogo, el observador se desactivará y no añadirá espacio vacío.
- Se mostrará un indicador compacto durante cada carga, sin alterar el tamaño de las tarjetas.

En el prototipo actual, la carga progresiva revelará elementos de `mediaItems`. Si más adelante el catálogo proviene de una API, la misma interfaz admitirá cursor o paginación sin rediseñar la vista.

### Búsqueda y filtros

Cuando el usuario escriba:

- Se conservará el filtrado actual por título, género, reparto, dirección y sinopsis.
- El resultado filtrado se mostrará también por lotes.
- Cambiar consulta o filtro reiniciará la cantidad visible al primer lote.
- El contador mostrará el total real de coincidencias, no solo los elementos visibles.
- Una consulta sin resultados conservará el estado vacío existente.

Las categorías de contenido se tomarán de los datos; no se crearán resultados ficticios para completar el scroll.

### Rendimiento y scroll

- Usar un único `IntersectionObserver` y desconectarlo al desmontar la vista.
- Memorizar el filtrado existente.
- Evitar listeners globales de scroll.
- Mantener la cuadrícula actual de tres columnas en Android.
- No introducir scroll horizontal.
- El cierre del contenido debe conservar un espacio inferior consistente con Inicio y Mi Biblioteca, sin una zona vacía exagerada.

## Estados y errores

- Carga de lote: indicador pequeño al final de la cuadrícula.
- Catálogo agotado: cierre limpio, sin botón ni mensaje pesado.
- Datos vacíos: estado vacío existente o invitación a explorar cuando corresponda.
- Persistencia de perfiles fallida: recuperar una lista vacía y solicitar crear el primer perfil.
- Avatar inexistente: utilizar un avatar local de respaldo sin romper el perfil.

## Estrategia de implementación

### Fase A — Perfiles

1. Separar la selección y edición de perfiles del `App` principal.
2. Crear el almacenamiento versionado y sus validaciones.
3. Sustituir los perfiles de demostración del arranque por perfiles creados por el usuario.
4. Implementar creación, selección, edición y eliminación.
5. Verificar primera ejecución, persistencia, límite de cinco y navegación.

### Fase B — Buscar

1. Mantener intactas las secciones existentes.
2. Añadir el catálogo completo y el estado de cantidad visible.
3. Añadir el observador de final y el indicador de carga.
4. Aplicar la misma paginación visual a resultados filtrados.
5. Verificar scroll, contadores, filtros, agotamiento y regreso desde Detalles.

## Criterios de aceptación

### Perfiles

- La primera ejecución obliga a crear un perfil.
- No existen Renata, Mateo o HourTV Kids como perfiles predeterminados.
- Nombre y avatar son obligatorios.
- El perfil infantil es configurable.
- Los perfiles sobreviven una recarga completa.
- Una nueva apertura siempre muestra el selector.
- Se pueden añadir, editar y eliminar perfiles hasta un máximo de cinco.
- No se puede eliminar el último perfil.
- No aparece Header ni Bottom Navigation antes de elegir.
- No hay perfiles preseleccionados ni foco persistente por clic.

### Buscar

- El diseño existente permanece reconocible e intacto.
- `Explorar catálogo` incluye todos los tipos de contenido disponibles.
- La cuadrícula carga 9 elementos y después lotes de 6.
- Los resultados de búsqueda también se revelan progresivamente.
- El contador representa el total real.
- No hay tarjetas duplicadas, scroll horizontal ni espacio final exagerado.
- El observador se limpia al abandonar Buscar.
- Las tarjetas continúan abriendo Detalles y conservan las acciones existentes.

## QA final

- Pruebas de comportamiento rojo-verde para primera ejecución y carga progresiva.
- Recarga completa con y sin perfiles guardados.
- Creación, selección, edición y eliminación de perfiles.
- Verificación de todos los avatares y del perfil infantil.
- Scroll completo de Buscar con catálogo agotado.
- Cambio de consulta y filtros mientras hay lotes cargados.
- Targets táctiles mínimos de 48 px.
- Cero desbordamiento horizontal.
- Sin errores de compilación ni consola.
- Inicio, TV, Detalles, Biblioteca y Perfil sin regresiones visuales.
