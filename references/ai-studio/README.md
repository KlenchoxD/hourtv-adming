# HourTV Android — referencia aprobada de Google AI Studio

Esta carpeta conserva la exportación exacta que actúa como única autoridad visual para la migración nativa de Android móvil.

## Identidad de la referencia

- Fecha de exportación: 2026-08-26
- Aplicación: HourTV Android Streaming
- Fuente: `https://aistudio.google.com/apps/c7f27888-c959-425b-a554-e27ab5885c6d`
- Archivo: `hourtv-android-streaming-2026-08-26.zip`
- SHA-256: `ED0D1FC439FC1CADFC0162ECFCBA0F050E973A1736CCEE0D93019AFCC84A53C0`
- Viewport visual de referencia: Android móvil en orientación vertical; el reproductor también incluye orientación horizontal.

El ZIP es inmutable. Si Google AI Studio cambia, se debe exportar un archivo nuevo con fecha y hash nuevos; no se sustituye silenciosamente esta referencia.

## Inventario obligatorio

- `ProfileGate.tsx`
- `AccessView.tsx`
- `HomeView.tsx`
- `OriginalsView.tsx`
- `LiveTvView.tsx`
- `SearchView.tsx`
- `LibraryView.tsx`
- `DetailsView.tsx`
- `PlayerView.tsx`
- `ProfileView.tsx`
- `SystemStatesView.tsx`
- Componentes comunes: logo, encabezado, botones, tarjetas, navegación inferior, hojas modales, snackbar y PIN parental.

## Fundamentos visuales

- Fondo: `#080A09`
- Superficie: `#101412`
- Superficie elevada: `#151917`
- Acento HourTV: `#00C781`
- Texto principal: `#F5F5F5`
- Texto secundario: `#C4C8C6`
- Texto atenuado: `#A8ADAB`
- Borde: `#27302C`
- Tipografía: Inter

## Regla de implementación

El contenido de este ZIP se traduce a widgets Flutter nativos. No se integra mediante WebView, no se usan capturas como pantallas y no se reemplazan los servicios existentes de catálogo, IPTV, reproducción, casting, favoritos, historial, perfiles o ajustes.

La verificación se ejecuta con:

```powershell
powershell -ExecutionPolicy Bypass -File tool/verify_ai_studio_reference.ps1
```
