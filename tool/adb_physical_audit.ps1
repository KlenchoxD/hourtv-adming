# ADB Physical Audit Script for HourTV on device 15d991620508
param(
    [string]$DeviceSerial = "15d991620508"
)

$adb = "C:\Users\Kleiner\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$pkg = "com.example.mi_app"
$artifactDir = "artifacts\adb_audit_20260913"

if (!(Test-Path $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}

Write-Output "=================================================="
Write-Output "INICIANDO AUDITORÍA FÍSICA EN DISPOSITIVO $DeviceSerial"
Write-Output "=================================================="

# Capturar estado original
$origWmSize = & $adb -s $DeviceSerial shell wm size
$origWmDensity = & $adb -s $DeviceSerial shell wm density
$origWifi = & $adb -s $DeviceSerial shell settings get global wifi_on

Write-Output "Estado Original: $origWmSize | $origWmDensity | Wi-Fi: $origWifi"

try {
    # ---------------------------------------------------------
    # 1. ARRANQUE FRÍO Y MEDICIÓN TTI
    # ---------------------------------------------------------
    Write-Output "`n[1/7] Midiendo Arranque Frío y TTI..."
    & $adb -s $DeviceSerial shell am force-stop $pkg
    Start-Sleep -Seconds 1
    & $adb -s $DeviceSerial logcat -c
    
    $coldStartOut = & $adb -s $DeviceSerial shell am start-activity -W -n "$pkg/.MainActivity"
    Write-Output "Cold Start Output:"
    Write-Output $coldStartOut
    $coldStartOut | Out-File "$artifactDir\cold_start_result.txt" -Encoding utf8
    
    Start-Sleep -Seconds 4
    & $adb -s $DeviceSerial shell screencap -p /sdcard/01_cold_start_home.png
    & $adb -s $DeviceSerial pull /sdcard/01_cold_start_home.png "$artifactDir\01_cold_start_home.png" | Out-Null
    
    # ---------------------------------------------------------
    # 2. ARRANQUE CALIENTE
    # ---------------------------------------------------------
    Write-Output "`n[2/7] Midiendo Arranque Caliente..."
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_HOME
    Start-Sleep -Seconds 2
    
    $warmStartOut = & $adb -s $DeviceSerial shell am start-activity -W -n "$pkg/.MainActivity"
    Write-Output "Warm Start Output:"
    Write-Output $warmStartOut
    $warmStartOut | Out-File "$artifactDir\warm_start_result.txt" -Encoding utf8
    Start-Sleep -Seconds 2

    # ---------------------------------------------------------
    # 3. SCROLL EN INICIO Y JANK DE RENDERIZADO (GFXINFO)
    # ---------------------------------------------------------
    Write-Output "`n[3/7] Midiendo Scroll Jank en Inicio (dumpsys gfxinfo)..."
    & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg reset | Out-Null
    
    for ($i = 0; $i -lt 4; $i++) {
        & $adb -s $DeviceSerial shell input swipe 540 1800 540 600 200
        Start-Sleep -Milliseconds 300
    }
    for ($i = 0; $i -lt 4; $i++) {
        & $adb -s $DeviceSerial shell input swipe 540 600 540 1800 200
        Start-Sleep -Milliseconds 300
    }
    
    $gfxHome = & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg
    $gfxHome | Out-File "$artifactDir\gfxinfo_home_scroll.txt" -Encoding utf8
    & $adb -s $DeviceSerial shell screencap -p /sdcard/02_home_scrolled.png
    & $adb -s $DeviceSerial pull /sdcard/02_home_scrolled.png "$artifactDir\02_home_scrolled.png" | Out-Null
    Write-Output "Métricas gfxinfo de Inicio guardadas."

    # ---------------------------------------------------------
    # 4. PESTAÑA BUSCAR, FAST SCROLL Y BÚSQUEDA PROFUNDA
    # ---------------------------------------------------------
    Write-Output "`n[4/7] Navegando a Pestaña Buscar y probando Búsqueda..."
    # Tab Buscar en bottom nav (x=405, y=2280)
    & $adb -s $DeviceSerial shell input tap 405 2280
    Start-Sleep -Seconds 2
    
    & $adb -s $DeviceSerial shell screencap -p /sdcard/03_buscar_tab.png
    & $adb -s $DeviceSerial pull /sdcard/03_buscar_tab.png "$artifactDir\03_buscar_tab.png" | Out-Null
    
    # Búsqueda profunda
    Write-Output "Ejecutando búsqueda profunda de 'Matrix'..."
    & $adb -s $DeviceSerial shell input tap 540 220
    Start-Sleep -Milliseconds 800
    & $adb -s $DeviceSerial shell input text "Matrix"
    Start-Sleep -Seconds 2
    
    & $adb -s $DeviceSerial shell screencap -p /sdcard/04_buscar_matrix.png
    & $adb -s $DeviceSerial pull /sdcard/04_buscar_matrix.png "$artifactDir\04_buscar_matrix.png" | Out-Null
    
    # Ocultar teclado
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Milliseconds 500

    # ---------------------------------------------------------
    # 5. DETALLE DE CONTENIDO Y REPRODUCCIÓN
    # ---------------------------------------------------------
    Write-Output "`n[5/7] Abriendo ficha de contenido e inspeccionando interfaz..."
    # Tocar el primer resultado
    & $adb -s $DeviceSerial shell input tap 300 650
    Start-Sleep -Seconds 3
    
    & $adb -s $DeviceSerial shell screencap -p /sdcard/05_detail_screen.png
    & $adb -s $DeviceSerial pull /sdcard/05_detail_screen.png "$artifactDir\05_detail_screen.png" | Out-Null

    # Scroll hacia abajo en detalle para ver episodios/ficha
    & $adb -s $DeviceSerial shell input swipe 540 1800 540 900 300
    Start-Sleep -Seconds 1
    & $adb -s $DeviceSerial shell screencap -p /sdcard/06_detail_episodes.png
    & $adb -s $DeviceSerial pull /sdcard/06_detail_episodes.png "$artifactDir\06_detail_episodes.png" | Out-Null

    # Probar reproducción
    Write-Output "Probando reproducción..."
    & $adb -s $DeviceSerial shell input tap 540 1300
    Start-Sleep -Seconds 3
    & $adb -s $DeviceSerial shell screencap -p /sdcard/07_player_active.png
    & $adb -s $DeviceSerial pull /sdcard/07_player_active.png "$artifactDir\07_player_active.png" | Out-Null
    
    # Regresar del reproductor
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell screencap -p /sdcard/08_after_player_return.png
    & $adb -s $DeviceSerial pull /sdcard/08_after_player_return.png "$artifactDir\08_after_player_return.png" | Out-Null

    # Regresar a la pantalla principal
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Seconds 1

    # ---------------------------------------------------------
    # 6. PESTAÑA PERFIL / AUTENTICACIÓN
    # ---------------------------------------------------------
    Write-Output "`n[6/7] Verificando Pestaña de Perfil / Autenticación..."
    & $adb -s $DeviceSerial shell input tap 945 2280
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell screencap -p /sdcard/09_auth_profile.png
    & $adb -s $DeviceSerial pull /sdcard/09_auth_profile.png "$artifactDir\09_auth_profile.png" | Out-Null

    # ---------------------------------------------------------
    # 7. PRUEBA SIN CONEXIÓN Y RECUPERACIÓN (OFFLINE / ONLINE)
    # ---------------------------------------------------------
    Write-Output "`n[7/7] Probando Modo Sin Conexión (Offline) y Restauración de Red..."
    & $adb -s $DeviceSerial shell svc wifi disable
    Start-Sleep -Seconds 2
    
    # Volver a pestaña Inicio
    & $adb -s $DeviceSerial shell input tap 135 2280
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell screencap -p /sdcard/10_offline_mode.png
    & $adb -s $DeviceSerial pull /sdcard/10_offline_mode.png "$artifactDir\10_offline_mode.png" | Out-Null

    # Restaurar Wi-Fi
    & $adb -s $DeviceSerial shell svc wifi enable
    Start-Sleep -Seconds 3
    & $adb -s $DeviceSerial shell screencap -p /sdcard/11_online_restored.png
    & $adb -s $DeviceSerial pull /sdcard/11_online_restored.png "$artifactDir\11_online_restored.png" | Out-Null

    # ---------------------------------------------------------
    # 8. ADAPTACIÓN BIDIMENSIONAL Y ORIENTACIÓN
    # ---------------------------------------------------------
    Write-Output "Probando simulación de pantalla estrecha (<360dp)..."
    & $adb -s $DeviceSerial shell wm size 720x1600
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell screencap -p /sdcard/12_narrow_screen_720.png
    & $adb -s $DeviceSerial pull /sdcard/12_narrow_screen_720.png "$artifactDir\12_narrow_screen_720.png" | Out-Null

    Write-Output "`n¡AUDITORÍA FÍSICA EJECUTADA CON ÉXITO!"
}
finally {
    # ---------------------------------------------------------
    # RESTAURACIÓN OBLIGATORIA EN BLOQUE FINALLY
    # ---------------------------------------------------------
    Write-Output "`n=================================================="
    Write-Output "RESTAURANDO ESTADO ORIGINAL DEL DISPOSITIVO..."
    Write-Output "=================================================="
    & $adb -s $DeviceSerial shell wm size reset
    & $adb -s $DeviceSerial shell wm density reset
    & $adb -s $DeviceSerial shell svc wifi enable
    
    $finalWmSize = & $adb -s $DeviceSerial shell wm size
    $finalWmDensity = & $adb -s $DeviceSerial shell wm density
    $finalWifi = & $adb -s $DeviceSerial shell settings get global wifi_on
    
    Write-Output "Estado Final Restaurado: $finalWmSize | $finalWmDensity | Wi-Fi: $finalWifi"
}
