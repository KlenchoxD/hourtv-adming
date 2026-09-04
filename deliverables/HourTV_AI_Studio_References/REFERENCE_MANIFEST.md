# Manifest de referencias

## Referencias principales

- `01_TV_Inicio.png`: identidad, Hero, navegación, botones y carruseles.
- `02_TV_Peliculas.png`: densidad de contenido, tarjetas y selector de orden. La primera tarjeta aparece enfocada en la captura; Android no debe preseleccionarla.
- `05_TV_Detalle_Pelicula.png`: jerarquía de Hero, metadata, acciones y recomendaciones.
- `06_TV_Detalle_Serie.png`: plantilla compartida de detalles y carrusel de episodios.
- `07_TV_Perfil.png`: estructura del perfil. Android debe sustituir los iconos improvisados por iconos coherentes.
- `08_TV_Loading.png`: dirección visual del loading. La implementación debe usar animaciones ligeras y fluidas.

## Solo estructura

- `TV_Series_STRUCTURE_ONLY_IGNORE_FOCUS.png`: usar la cuadrícula y jerarquía; ignorar los múltiples bordes verdes y cualquier foco residual.
- `TV_Buscar_STRUCTURE_ONLY_ANDROID_SYSTEM_KEYBOARD.png`: usar la relación búsqueda/resultados; Android debe usar el teclado del sistema. Ignorar la A fija y el botón Volver del teclado TV.
- `TV_En_Vivo_STRUCTURE_ONLY_IGNORE_RED.png`: usar únicamente la arquitectura de información. Ignorar completamente el rojo y aplicar la paleta esmeralda actual.

## No cubierto visualmente

Mi Biblioteca y Reproductor no tienen un export TV limpio y actualizado en este paquete. Deben construirse según `MASTER_PROMPT.txt` y usando los mismos componentes, tokens y jerarquía del resto del sistema.

## Paleta obligatoria

- Deep Black: `#050505`
- Background Primary: `#080A09`
- Surface Primary: `#101412`
- Surface Control: `#151917`
- Border Subtle: `#27302C`
- Emerald: `#00C781`
- Text Primary: `#F5F5F5`
- Text Secondary: `#C4C8C6`
- Text Muted: `#A8ADAB`

