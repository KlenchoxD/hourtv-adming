# HourTV — paquete de referencias para Google AI Studio

Este paquete sirve para generar una propuesta Android completa conservando la identidad visual aprobada de HourTV TV.

## Orden recomendado

1. Abre Google AI Studio en `Build > New app`.
2. Adjunta `00_HourTV_TV_Reference_Board_UPLOAD.png`.
3. Adjunta `03_Brand_Assets/HourTV_Logo.png`.
4. Si AI Studio permite más archivos, adjunta las seis imágenes de `01_Primary_Visual_References`.
5. No adjuntes inicialmente `02_Structure_Only`. Úsala solo si AI Studio necesita entender Series, Buscar o TV en vivo.
6. Copia y pega todo el contenido de `MASTER_PROMPT.txt`.
7. Solicita que construya el prototipo antes de explicar la solución.

## Regla crítica

Las imágenes muestran la dirección visual y la arquitectura de TV. Android debe adaptarlas a una experiencia vertical y táctil; no debe copiar el Navigation Rail, el teclado TV ni las dimensiones 1920×1080.

La carpeta `02_Structure_Only` contiene referencias con estados antiguos. Sus nombres y `REFERENCE_MANIFEST.md` explican qué debe ignorarse.

## Si existe un límite de archivos

Sube solamente:

- `00_HourTV_TV_Reference_Board_UPLOAD.png`
- `03_Brand_Assets/HourTV_Logo.png`
- `MASTER_PROMPT.txt`, si AI Studio acepta texto como archivo; de lo contrario, pégalo en el campo principal.

## Qué devolver a Codex

Cuando AI Studio termine, conserva:

- enlace del prototipo;
- proyecto o código descargado;
- capturas de cada ruta Android;
- informe de QA generado por AI Studio.

