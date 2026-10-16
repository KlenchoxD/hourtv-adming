# HourTV 1.1.52 (55): restauración del reproductor

## Causa

La release 1.1.51 se compiló desde una rama que no contenía el rediseño
local instalado como 1.1.49 (53). Se incrementó la versión sin integrar esos
archivos y sus dependencias. La interfaz antigua volvió dentro de un APK nuevo.

La rama de esta release conserva el código fuente del rediseño, sus pruebas,
la pila nativa usada en el build 53 y la corrección del catálogo de e5e7c6e.
Los cinco archivos del reproductor y menús son idénticos al snapshot 8d8fa8f.
Los conflictos del catálogo conservan ContinueWatchingEntry (portada de serie),
eliminan los fallbacks VOD antiguos y respetan el panel publicado vacío.

## Verificación

- 48/48 pruebas dirigidas: cabecera, menús, centro, buffering, fundido por toque
  y timeout, recuperación de motores, ContentStore, parser y fallback del catálogo.
- Análisis de los diez archivos integrados: sin errores ni warnings; dos avisos
  informativos de llaves de estilo en hourtv_new_shell.dart (exit 0).
- APK release compilado correctamente: 198083846 bytes, versionName 1.1.52,
  versionCode 55. Firma SHA256 del certificado: 
  eda69c3ec3f2fd473be097b75d86a9fc76bdc265f59985260138ffc167ba7d2d.
  SHA256 del APK: BA91D54722636EA9161E79CB701499E431E04CB8721799447A9F39D9C2E717D5.
- Suite completa: 755 pasaron, 3 omitidas, 18 fallaron. No se declara verde.
- El Infinix estaba conectado al comenzar (1.1.51, build 54), pero se desconectó
  antes de la instalación de esta actualización. La comprobación física queda
  pendiente hasta que vuelva a estar disponible por ADB.

## Fallos generales pendientes

Los siguientes archivos contienen las 18 pruebas fallidas de la ejecución
completa. Algunos casos esperan datos de Drift/caché que la migración del
catálogo ahora descarta; otros dejan timers de arranque pendientes. No se han
clasificado todos como fallos previos ni se ha cambiado producción para ocultarlos.

- archive_movies_removed_test.dart: selección del catálogo de prueba.
- guest_migration_service_test.dart: conteos de inspección de invitado.
- hourtv_mobile_search_filters_test.dart: filtro de Series.
- hourtv_mobile_ui_test.dart: tema y cinco destinos (2).
- hourtv_profile_navigation_crash_test.dart: cambio de perfil.
- live_tab_pauses_on_switch_test.dart: cambio de pestaña TV.
- mobile_lazy_pages_test.dart: montaje diferido de destinos (2).
- new_ui/hourtv_new_shell_tv_tablet_test.dart: datos Drift y navegación (4).
- new_ui/hourtv_tv_recommendations_widget_test.dart: recomendaciones (2).
- profile_gate_test.dart: selección inicial de perfil.
- services/sync/production_bootstrap_integration_test.dart: recomendaciones.
- startup_readiness_test.dart: recuperación del catálogo antiguo sin red.

Estos pendientes son independientes de la confirmación de las pruebas dirigidas
del rediseño. MHDPlus está cancelado por solicitud del usuario; no se retoma.
