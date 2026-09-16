param(
    [string]$DeviceSerial = "15d991620508"
)

$adb = "C:\Users\Kleiner\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$pkg = "com.example.mi_app"
$artifactDir = "artifacts\adb_audit_20260913"

if (!(Test-Path $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}

Write-Output "=========================================================="
Write-Output "EJECUTANDO FASE DE AUDITORÍA FÍSICA DETALLADA EN $DeviceSerial"
Write-Output "=========================================================="

try {
    # -------------------------------------------------------------
    # PASO A: DETALLE DE PELÍCULA ("Backrooms")
    # -------------------------------------------------------------
    Write-Output "`n[A] Abriendo Detalle de Película (Backrooms)..."
    # Asegurar que estamos en Inicio y tocar tarjeta Backrooms (x=180, y=740)
    & $adb -s $DeviceSerial shell input tap 108 2180
    Start-Sleep -Seconds 1
    & $adb -s $DeviceSerial shell input tap 180 740
    Start-Sleep -Seconds 3

    & $adb -s $DeviceSerial shell screencap -p /sdcard/07_movie_detail.png
    & $adb -s $DeviceSerial pull /sdcard/07_movie_detail.png "$artifactDir\07_movie_detail.png" | Out-Null
    Write-Output "07_movie_detail.png guardado."

    # -------------------------------------------------------------
    # PASO B: REPRODUCCIÓN Y PROGRESO DE REPRODUCCIÓN
    # -------------------------------------------------------------
    Write-Output "`n[B] Iniciando reproducción para registrar progreso..."
    # Tocar botón REPRODUCIR en detalle (x=540, y=1050 aprox o swipe up si necesario)
    & $adb -s $DeviceSerial shell input tap 540 1000
    Start-Sleep -Seconds 4

    & $adb -s $DeviceSerial shell screencap -p /sdcard/09_player_screen.png
    & $adb -s $DeviceSerial pull /sdcard/09_player_screen.png "$artifactDir\09_player_screen.png" | Out-Null
    Write-Output "09_player_screen.png guardado."

    # Regresar del reproductor y verificar progreso retenido
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell screencap -p /sdcard/10_progress_retained.png
    & $adb -s $DeviceSerial pull /sdcard/10_progress_retained.png "$artifactDir\10_progress_retained.png" | Out-Null
    Write-Output "10_progress_retained.png guardado."

    # Regresar a Inicio
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Seconds 1

    # -------------------------------------------------------------
    # PASO C: DETALLE DE SERIE Y EPISODIOS VIRTUALIZADOS
    # -------------------------------------------------------------
    Write-Output "`n[C] Abriendo Detalle de Serie (Avatar Aang)..."
    & $adb -s $DeviceSerial shell input tap 108 2180
    Start-Sleep -Seconds 1
    # Tocar tarjeta de Avatar Aang (x=860, y=740)
    & $adb -s $DeviceSerial shell input tap 860 740
    Start-Sleep -Seconds 3

    & $adb -s $DeviceSerial shell screencap -p /sdcard/08_series_detail.png
    & $adb -s $DeviceSerial pull /sdcard/08_series_detail.png "$artifactDir\08_series_detail.png" | Out-Null
    Write-Output "08_series_detail.png guardado."

    # Scroll hacia abajo para ver lista de episodios virtualizada (SliverList.builder)
    Write-Output "Scrolleando para inspeccionar lista de episodios virtualizada..."
    & $adb -s $DeviceSerial shell input swipe 540 1800 540 800 300
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell screencap -p /sdcard/08b_series_episodes.png
    & $adb -s $DeviceSerial pull /sdcard/08b_series_episodes.png "$artifactDir\08b_series_episodes.png" | Out-Null
    Write-Output "08b_series_episodes.png guardado."

    # Regresar a Inicio
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Seconds 1

    # -------------------------------------------------------------
    # PASO D: PESTAÑA BUSCAR, BÚSQUEDA PROFUNDA Y JANK
    # -------------------------------------------------------------
    Write-Output "`n[D] Probando Pestaña Buscar y Búsqueda Profunda..."
    # Tocar BUSCAR (x=500, y=2180)
    & $adb -s $DeviceSerial shell input tap 500 2180
    Start-Sleep -Seconds 2

    # Tocar campo de búsqueda
    & $adb -s $DeviceSerial shell input tap 450 350
    Start-Sleep -Milliseconds 500
    & $adb -s $DeviceSerial shell input text "Matrix"
    Start-Sleep -Milliseconds 800
    # Tocar flecha de búsqueda verde
    & $adb -s $DeviceSerial shell input tap 900 350
    Start-Sleep -Seconds 2

    # Ocultar teclado
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Seconds 1

    & $adb -s $DeviceSerial shell screencap -p /sdcard/04_buscar_matrix_results.png
    & $adb -s $DeviceSerial pull /sdcard/04_buscar_matrix_results.png "$artifactDir\04_buscar_matrix_results.png" | Out-Null
    Write-Output "04_buscar_matrix_results.png guardado."

    # Medir Jank en resultados de búsqueda
    & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg reset | Out-Null
    for ($i = 0; $i -lt 3; $i++) {
        & $adb -s $DeviceSerial shell input swipe 540 1600 540 700 200
        Start-Sleep -Milliseconds 250
    }
    for ($i = 0; $i -lt 3; $i++) {
        & $adb -s $DeviceSerial shell input swipe 540 700 540 1600 200
        Start-Sleep -Milliseconds 250
    }
    $gfxSearch = & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg
    $gfxSearch | Out-File "$artifactDir\gfxinfo_search_scroll.txt" -Encoding utf8
    Write-Output "Métricas gfxinfo de búsqueda guardadas."

    # -------------------------------------------------------------
    # PASO E: PERFIL Y COMPORTAMIENTO DE GOOGLE NO CONFIGURADO
    # -------------------------------------------------------------
    Write-Output "`n[E] Verificando Pestaña Perfil y Google OAuth no configurado..."
    # Tocar PERFIL (x=900, y=2180)
    & $adb -s $DeviceSerial shell input tap 900 2180
    Start-Sleep -Seconds 2

    & $adb -s $DeviceSerial shell screencap -p /sdcard/11a_auth_page.png
    & $adb -s $DeviceSerial pull /sdcard/11a_auth_page.png "$artifactDir\11a_auth_page.png" | Out-Null
    Write-Output "11a_auth_page.png guardado."

    # Tocar botón de Google (si está en la pantalla de auth)
    # Normalmente el botón de Google está centrado alrededor de y=1400-1600
    # Inspeccionamos la pantalla o presionamos donde suele estar
    & $adb -s $DeviceSerial shell input tap 540 1550
    Start-Sleep -Seconds 2

    & $adb -s $DeviceSerial shell screencap -p /sdcard/11b_google_unconfigured.png
    & $adb -s $DeviceSerial pull /sdcard/11b_google_unconfigured.png "$artifactDir\11b_google_unconfigured.png" | Out-Null
    Write-Output "11b_google_unconfigured.png guardado."

    # -------------------------------------------------------------
    # PASO F: MODO OFFLINE Y RECUPERACIÓN ONLINE
    # -------------------------------------------------------------
    Write-Output "`n[F] Probando Modo Offline..."
    & $adb -s $DeviceSerial shell svc wifi disable
    Start-Sleep -Seconds 2
    # Ir a Inicio
    & $adb -s $DeviceSerial shell input tap 108 2180
    Start-Sleep -Seconds 2

    & $adb -s $DeviceSerial shell screencap -p /sdcard/12_offline_mode.png
    & $adb -s $DeviceSerial pull /sdcard/12_offline_mode.png "$artifactDir\12_offline_mode.png" | Out-Null
    Write-Output "12_offline_mode.png guardado."

    # Restaurar Wi-Fi
    Write-Output "Restaurando Wi-Fi online..."
    & $adb -s $DeviceSerial shell svc wifi enable
    Start-Sleep -Seconds 3

    & $adb -s $DeviceSerial shell screencap -p /sdcard/13_online_restored.png
    & $adb -s $DeviceSerial pull /sdcard/13_online_restored.png "$artifactDir\13_online_restored.png" | Out-Null
    Write-Output "13_online_restored.png guardado."

    # -------------------------------------------------------------
    # PASO G: ORIENTACIÓN VERTICAL / HORIZONTAL Y ADAPTACIÓN VISUAL
    # -------------------------------------------------------------
    Write-Output "`n[G] Probando Rotación Horizontal (Landscape)..."
    & $adb -s $DeviceSerial shell settings put system accelerometer_rotation 0
    & $adb -s $DeviceSerial shell settings put system user_rotation 1
    Start-Sleep -Seconds 3

    & $adb -s $DeviceSerial shell screencap -p /sdcard/14_landscape_mode.png
    & $adb -s $DeviceSerial pull /sdcard/14_landscape_mode.png "$artifactDir\14_landscape_mode.png" | Out-Null
    Write-Output "14_landscape_mode.png guardado."

    # Restaurar orientación vertical
    & $adb -s $DeviceSerial shell settings put system user_rotation 0
    Start-Sleep -Seconds 2

    Write-Output "Probando pantalla estrecha (720x1600)..."
    & $adb -s $DeviceSerial shell wm size 720x1600
    Start-Sleep -Seconds 2

    & $adb -s $DeviceSerial shell screencap -p /sdcard/15_narrow_screen_720.png
    & $adb -s $DeviceSerial pull /sdcard/15_narrow_screen_720.png "$artifactDir\15_narrow_screen_720.png" | Out-Null
    Write-Output "15_narrow_screen_720.png guardado."

    Write-Output "`nTODAS LAS PRUEBAS FÍSICAS COMPLETADAS EXITOSAMENTE."
}
finally {
    Write-Output "`n=========================================================="
    Write-Output "FINALLY: RESTAURANDO ESTADO ORIGINAL DEL DISPOSITIVO..."
    Write-Output "=========================================================="
    & $adb -s $DeviceSerial shell wm size reset
    & $adb -s $DeviceSerial shell wm density reset
    & $adb -s $DeviceSerial shell settings put system accelerometer_rotation 1
    & $adb -s $DeviceSerial shell settings put system user_rotation 0
    & $adb -s $DeviceSerial shell svc wifi enable

    $fSize = & $adb -s $DeviceSerial shell wm size
    $fDensity = & $adb -s $DeviceSerial shell wm density
    $fWifi = & $adb -s $DeviceSerial shell settings get global wifi_on
    Write-Output "Estado Final: $fSize | $fDensity | Wi-Fi: $fWifi"
}
