# HourTV AutoCatálogo

Bot que actualiza `catalog.json` de forma automática, sin intervención
humana, usando [TMDB](https://www.themoviedb.org/) para la ficha de cada
película y "proveedores de contenido" configurables para las URLs de
reproducción. Se ejecuta con GitHub Actions cada 6 horas
(`.github/workflows/hourtv-auto-catalog.yml`) y también se puede lanzar
manualmente.

**No hace scraping ni evade protecciones de sitios de streaming.** Solo
publica una película si un proveedor autorizado (configurado por ti) entrega
una URL de reproducción válida. Si no hay fuente, la película no se agrega y
queda registrada como omitida con el motivo.

El panel `admin/index.html` sigue funcionando igual que antes, como editor
manual y visor: el bot y el panel leen/escriben el mismo `catalog.json` y no
se pisan entre sí (el bot nunca borra películas existentes y, por defecto, no
modifica las que ya están en el catálogo).

## Qué hace en cada ejecución

1. Consulta `discover/movie` (estrenos de los últimos `RULE_RECENT_DAYS` días)
   y `movie/popular` en TMDB, en español (`es-ES`) y región `CO`.
2. Para cada candidato, pide detalles + créditos (reparto, director,
   guionistas) y arma la ficha completa.
3. Descarta duplicados comparando por `tmdbId` (o por título normalizado +
   año en películas antiguas que no tengan `tmdbId`).
4. Aplica las reglas de calidad (rating mínimo, votos mínimos, póster,
   sinopsis, fecha válida, idioma original, contenido adulto).
5. Calcula categorías automáticamente a partir de los géneros de TMDB.
6. Decide si la película debe ir "destacada" según reglas objetivas de
   popularidad/rating/recencia (máximo configurable por ejecución y en total).
7. Pregunta a los proveedores de reproducción configurados
   (`OwnCatalogProvider` / `HttpProvider`) si tienen una fuente para esa
   película. Si ninguno responde, la película **no se publica**.
8. Valida cada URL candidata con una petición HTTP `HEAD`/`GET` con timeout
   antes de aceptarla.
9. Si hay al menos una fuente válida, añade la película a `catalog.json`.
   Si no, la registra como omitida.
10. Escribe `data/automation-state.json` (estado acumulado) y
    `data/automation-report.json` (reporte de esa ejecución).

## Variables de entorno

### Obligatorias

| Variable       | Descripción                                    |
| -------------- | ----------------------------------------------- |
| `TMDB_API_KEY` | API key de TMDB (v3 auth). Ver sección abajo.    |

### Proveedores de reproducción (al menos uno para que se publiquen películas)

| Variable                    | Descripción                                                        |
| ---------------------------- | ------------------------------------------------------------------- |
| `OWN_CATALOG_URL`            | URL de un JSON con tus propias fuentes (ver `data/provider-config.example.json`). |
| `CONTENT_PROVIDER_API_URL`   | URL base de una API propia/legítima que resuelva fuentes por `tmdbId`. |
| `CONTENT_PROVIDER_API_KEY`   | Clave de autorización para esa API (se envía como `Authorization: Bearer`). |

### Reglas (opcionales, todas tienen un valor por defecto razonable)

| Variable                       | Por defecto | Descripción                                            |
| ------------------------------- | ----------- | ------------------------------------------------------- |
| `RULE_ORIGINAL_LANGUAGE`        | `any`       | `es`, `en` o `any`.                                      |
| `RULE_EXCLUDE_ADULT`            | `true`      | Excluir contenido para adultos.                          |
| `RULE_EXCLUDE_NO_POSTER`        | `true`      | Excluir películas sin póster.                            |
| `RULE_EXCLUDE_NO_PLOT`          | `true`      | Excluir películas sin sinopsis.                          |
| `RULE_EXCLUDE_NO_DATE`          | `true`      | Excluir películas sin fecha de estreno válida.           |
| `RULE_MIN_RATING`               | `5.5`       | Rating mínimo de TMDB (0–10).                             |
| `RULE_MIN_VOTES`                | `50`        | Votos mínimos en TMDB.                                    |
| `RULE_RECENT_DAYS`              | `120`       | Ventana de días para considerar "estreno".                |
| `RULE_MAX_ADD_PER_RUN`          | `10`        | Máximo de películas nuevas por ejecución.                 |
| `RULE_MAX_CATALOG_SIZE`         | `2000`      | Tamaño máximo total del catálogo.                         |
| `RULE_MAX_FEATURED_NEW_PER_RUN` | `2`         | Máximo de nuevas destacadas por ejecución.                 |
| `RULE_MAX_FEATURED_TOTAL`       | `8`         | Máximo de destacadas totales en el catálogo.               |
| `RULE_ENRICH_EXISTING`          | `false`     | Si es `true`, cuando un candidato TMDB coincide con una película ya existente, rellena solo los campos vacíos (sinopsis, reparto, director, guionista, género, rating, duración, póster, backdrop, `tmdbId`). Nunca sobrescribe un valor ya presente ni toca `id`, `servers`, `categories` o `featured`. Por defecto no se toca ninguna película existente. |

### Ejecución (las controla el workflow, o se pueden fijar a mano)

| Variable        | Descripción                                          |
| ---------------- | ----------------------------------------------------- |
| `DRY_RUN`         | `true` = simula todo sin escribir `catalog.json`.      |
| `MAX_ITEMS`       | Sobrescribe `RULE_MAX_ADD_PER_RUN` para una corrida puntual. |
| `FORCE_REFRESH`   | Reservado para saltarse cachés futuras (hoy no hay caché persistente entre corridas más allá del propio `catalog.json`). |

## Cómo obtener una API key de TMDB

1. Crea una cuenta gratuita en [themoviedb.org](https://www.themoviedb.org/signup).
2. Ve a tu perfil → **Configuración** → **API**.
3. Solicita una **API key (v3 auth)** describiendo el uso (proyecto personal /
   catálogo de películas).
4. Copia la clave generada; es el valor de `TMDB_API_KEY`.

## Cómo crear los GitHub Secrets

En el repositorio de GitHub: **Settings → Secrets and variables → Actions →
New repository secret**. Crea como mínimo:

- `TMDB_API_KEY`
- `OWN_CATALOG_URL` (si vas a usar tu propio catálogo/CDN)
- `CONTENT_PROVIDER_API_URL` y `CONTENT_PROVIDER_API_KEY` (si vas a usar un
  proveedor con API)

No hace falta crear `GITHUB_TOKEN`: GitHub Actions lo genera automáticamente
en cada ejecución con los permisos declarados en el workflow
(`permissions: contents: write`).

## Conectar tu propio scraper (Server Hunter)

Si ya usas **Server Hunter** (`server-hunter-main`, la app de escritorio con
la que analizas manualmente una página y ella detecta los reproductores
embebidos por idioma), no hace falta reimplementar nada: hay un conversor
listo en [`automation/tools/server_hunter_sync.py`](tools/server_hunter_sync.py)
que traduce lo que Server Hunter ya encontró al formato que espera
`OwnCatalogProvider`.

Flujo completo:

1. Analiza páginas con Server Hunter como siempre (tú pegas la URL, tú pulsas
   "Iniciar scraping"). Cada resultado queda en su base de datos local
   (`server_hunter.db`) o lo puedes exportar a JSON desde su interfaz.
2. Ejecuta el conversor (requiere Python 3 y tu `TMDB_API_KEY`, la misma que
   usa el bot):

   ```powershell
   cd automation/tools
   $env:TMDB_API_KEY = "tu_clave_tmdb"
   python server_hunter_sync.py
   ```

   Por defecto busca `server_hunter.db` en las rutas habituales (modo
   desarrollo o instalado). Si la tienes en otro sitio: `--db "C:\ruta\server_hunter.db"`,
   o si prefieres partir de JSON exportados manualmente: `--exports-dir "C:\ruta\a\los\json"`.

3. Revisa `automation/tools/own-catalog.generated.json`:
   - **`entries`** — coincidencias donde el título encontrado coincidió
     exactamente con un título de TMDB. Listas para publicar.
   - **`needsReview`** — TMDB no tuvo un título idéntico; se guarda el mejor
     candidato para que decidas a mano si es correcto.
   - **`unmatched`** — TMDB no encontró nada para ese título.
4. Copia (o fusiona) el array `entries` dentro del JSON que publiques como
   `OWN_CATALOG_URL` — por ejemplo, un archivo `data/own-catalog.json` en
   este mismo repositorio, servido después vía
   `https://raw.githubusercontent.com/<owner>/<repo>/main/data/own-catalog.json`.

El conversor solo lee datos que Server Hunter ya extrajo de páginas que tú
elegiste analizar manualmente; no abre navegadores, no visita sitios nuevos
ni decide qué scrapear.

## Cómo configurar `OWN_CATALOG_URL`

Aloja un JSON público (por ejemplo en otro repositorio, un bucket S3 público,
o cualquier hosting estático) con este formato:

```json
{
  "entries": [
    {
      "tmdbId": 550,
      "language": "Español",
      "serverName": "CDN propio",
      "url": "https://cdn.tu-servicio-autorizado.com/videos/fight-club.m3u8"
    }
  ]
}
```

Un mismo `tmdbId` puede repetirse con distintos `language` para ofrecer
varios idiomas; el bot los agrupa todos como servidores de esa película. Ver
`data/provider-config.example.json` para más ejemplos.

## Cómo configurar un proveedor HTTP

Si en cambio tienes una API propia o de un proveedor legítimo, define:

- `CONTENT_PROVIDER_API_URL`: por ejemplo `https://api.tu-proveedor.com/resolve`
- `CONTENT_PROVIDER_API_KEY`: token que se enviará como `Authorization: Bearer <token>`

El bot hará `GET {CONTENT_PROVIDER_API_URL}?tmdbId=550&title=...&year=1999` y
espera una respuesta como:

```json
{
  "sources": [
    { "url": "https://...", "serverName": "Servidor 1", "language": "Español" }
  ]
}
```

Un `404` se interpreta como "sin fuente para esta película" (no es un
error). Cualquier otro código de error se registra y esa película se omite,
sin detener el resto de la ejecución.

## Cómo ejecutar manualmente el workflow

1. En GitHub, pestaña **Actions** → **HourTV AutoCatálogo** → **Run workflow**.
2. Opcionalmente marca `dry_run` para simular sin publicar, define
   `max_items` para limitar cuántas se añaden, o `force_refresh`.
3. Pulsa **Run workflow**.

## Cómo revisar el reporte

Cada ejecución sube un artifact llamado **hourtv-automation-report** con:

- `data/automation-report.json`: resumen de esa corrida (encontradas,
  añadidas, descartadas, duplicados, errores, duración).
- `data/automation-state.json`: estado acumulado (últimos `tmdbId` revisados
  y publicados, errores recientes, lista de omitidos con motivo).

Descárgalo desde la página de la ejecución en la pestaña **Actions**. Ambos
archivos también quedan committeados en `data/` en cada ejecución real (no en
`dry_run`), así que también puedes verlos directamente en el repositorio.

## Cómo desactivar el bot

- **Temporalmente**: en **Actions → HourTV AutoCatálogo**, botón **⋯ → Disable workflow**.
- **Definitivamente**: borra o renombra
  `.github/workflows/hourtv-auto-catalog.yml`.

El panel `admin/index.html` sigue funcionando exactamente igual en ambos
casos, ya que es independiente del workflow.

## Qué ocurre si no existen fuentes válidas

Si no configuras `OWN_CATALOG_URL` ni `CONTENT_PROVIDER_API_URL`, el bot
sigue ejecutándose (revisa TMDB, genera el reporte), pero **no añade ninguna
película nueva**: todas quedan registradas en `skipped` con el motivo "Sin
fuente autorizada configurada". Esto es intencional — nunca se inventa ni se
scrapea una URL de reproducción.

## La app Flutter

La app ya lee `catalog.json` remoto desde
`raw.githubusercontent.com/KlenchoxD/hourtv-adming/main/catalog.json` (ver
`lib/services/content_store.dart`). No hace falta recompilar ni republicar la
app: en cuanto el bot hace commit del `catalog.json` actualizado, la
siguiente vez que la app revalide en segundo plano (o el usuario refresque),
verá el contenido nuevo. El formato de cada película es 100% compatible con
el que ya usa `admin/index.html` — el bot solo agrega objetos con esos mismos
campos, más un `tmdbId` adicional para deduplicar en el futuro.
