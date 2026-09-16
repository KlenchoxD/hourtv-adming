# PowerShell Physical Audit Runner for HourTV v1.1.14+16 on Xiaomi Redmi 10 (15d991620508)
param(
    [string]$DeviceSerial = "15d991620508"
)

$adb = "C:\Users\Kleiner\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$pkg = "com.example.mi_app"
$artifactDir = "artifacts\adb_audit_20260914"

if (!(Test-Path $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}

function Exec-Adb($cmd) {
    & $adb -s $DeviceSerial $cmd
}

Write-Output "=================================================="
Write-Output "INICIANDO AUDITORÍA FÍSICA DETALLADA (2026-09-14)"
Write-Output "Dispositivo: $DeviceSerial"
Write-Output "=================================================="

try {
    # 0. Configurar orientación retrato y estado limpio
    & $adb -s $DeviceSerial shell settings put system accelerometer_rotation 0
    & $adb -s $DeviceSerial shell settings put system user_rotation 0
    & $adb -s $DeviceSerial shell wm size reset
    & $adb -s $DeviceSerial shell wm density reset
    & $adb -s $DeviceSerial shell svc wifi enable
    Start-Sleep -Seconds 1

    # ---------------------------------------------------------
    # 1. TTI CON MARCAS PROPIAS Y ARRANQUE FRÍO
    # ---------------------------------------------------------
    Write-Output "`n[1/5] Midiendo Arranque Frío y TTI con Marcas Propias..."
    & $adb -s $DeviceSerial shell am force-stop $pkg
    Start-Sleep -Seconds 1
    & $adb -s $DeviceSerial logcat -c

    $intentStartMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $amStartOutput = & $adb -s $DeviceSerial shell am start-activity -W -n "$pkg/.MainActivity"
    Write-Output "am start output:"
    Write-Output $amStartOutput
    $amStartOutput | Out-File "$artifactDir\cold_start_am_output.txt" -Encoding utf8

    Start-Sleep -Seconds 4
    & $adb -s $DeviceSerial shell screencap -p /sdcard/01_auth_page.png
    & $adb -s $DeviceSerial pull /sdcard/01_auth_page.png "$artifactDir\01_auth_page.png" | Out-Null

    # Extraer marcas TTI de logcat
    $logcatLines = & $adb -s $DeviceSerial logcat -d -s "flutter"
    $logcatLines | Out-File "$artifactDir\startup_logcat.txt" -Encoding utf8

    $appBootLine = $logcatLines | Select-String -Pattern "\[PERF_TTI\] APP_BOOT: time=(\d+)" | Select-Object -First 1
    $canEnterLine = $logcatLines | Select-String -Pattern "\[PERF_TTI\] CatalogReadiness\.canEnterApp:.*time=(\d+)" | Select-Object -First 1
    $firstFrameLine = $logcatLines | Select-String -Pattern "\[PERF_TTI\] FIRST_INTERACTIVE_FRAME: time=(\d+)" | Select-Object -First 1

    Write-Output "Marcas TTI detectadas:"
    Write-Output "Intent start epoch: $intentStartMs"
    Write-Output "App Boot: $appBootLine"
    Write-Output "CanEnterApp: $canEnterLine"
    Write-Output "FirstFrame: $firstFrameLine"

    # ---------------------------------------------------------
    # 2. P0 AUTENTICACIÓN REAL Y CASOS
    # ---------------------------------------------------------
    Write-Output "`n[2/5] Verificando Proveedor Google no configurado..."
    # Tap Google button at x=540, y=1510
    & $adb -s $DeviceSerial shell input tap 540 1510
    Start-Sleep -Seconds 3
    & $adb -s $DeviceSerial shell screencap -p /sdcard/02_google_unconfigured.png
    & $adb -s $DeviceSerial pull /sdcard/02_google_unconfigured.png "$artifactDir\02_google_unconfigured.png" | Out-Null
    Write-Output "Evidencia de Google no configurado capturada en 02_google_unconfigured.png"

    # Regresar a la app HourTV si abrió Chrome
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Seconds 2

    # Probar Modo Invitado
    Write-Output "Probando Modo Invitado..."
    # Tap Continuar como invitado at x=540, y=1740
    & $adb -s $DeviceSerial shell input tap 540 1740
    Start-Sleep -Seconds 3
    & $adb -s $DeviceSerial shell screencap -p /sdcard/03_guest_mode.png
    & $adb -s $DeviceSerial pull /sdcard/03_guest_mode.png "$artifactDir\03_guest_mode.png" | Out-Null
    Write-Output "Modo Invitado capturado en 03_guest_mode.png"

    # ---------------------------------------------------------
    # 3. VERIFICACIÓN DE BÚSQUEDA Y FIX MATRIX
    # ---------------------------------------------------------
    Write-Output "`n[3/5] Verificando Búsqueda ('Matrix', inexistente, borrar, último item)..."
    # Tap pestaña BUSCAR en bottom nav: x=540, y=2125
    & $adb -s $DeviceSerial shell input tap 540 2125
    Start-Sleep -Seconds 2

    # Tap caja de texto de búsqueda: x=400, y=210
    & $adb -s $DeviceSerial shell input tap 400 210
    Start-Sleep -Milliseconds 500

    # Búsqueda 1: "Matrix"
    Write-Output "Ejecutando búsqueda 'Matrix'..."
    & $adb -s $DeviceSerial shell input text "Matrix"
    Start-Sleep -Seconds 2
    # Ocultar teclado
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Milliseconds 500
    & $adb -s $DeviceSerial shell screencap -p /sdcard/06_search_matrix.png
    & $adb -s $DeviceSerial pull /sdcard/06_search_matrix.png "$artifactDir\06_search_matrix.png" | Out-Null

    # Búsqueda 2: "InexistenteX999"
    Write-Output "Ejecutando búsqueda inexistente..."
    # Tap clear button o seleccionar y borrar
    & $adb -s $DeviceSerial shell input tap 1000 210 # suffix icon (arrow / clear)
    Start-Sleep -Milliseconds 500
    # Seleccionar caja de texto
    & $adb -s $DeviceSerial shell input tap 400 210
    Start-Sleep -Milliseconds 300
    # Seleccionar todo y borrar
    for ($b = 0; $b -lt 15; $b++) { & $adb -s $DeviceSerial shell input keyevent KEYCODE_DEL }
    & $adb -s $DeviceSerial shell input text "InexistenteX999"
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Milliseconds 500
    & $adb -s $DeviceSerial shell screencap -p /sdcard/07_search_nonexistent.png
    & $adb -s $DeviceSerial pull /sdcard/07_search_nonexistent.png "$artifactDir\07_search_nonexistent.png" | Out-Null

    # Búsqueda 3: Borrar consulta -> restaura catálogo
    Write-Output "Borrando consulta..."
    & $adb -s $DeviceSerial shell input tap 400 210
    Start-Sleep -Milliseconds 300
    for ($b = 0; $b -lt 20; $b++) { & $adb -s $DeviceSerial shell input keyevent KEYCODE_DEL }
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Milliseconds 500
    & $adb -s $DeviceSerial shell screencap -p /sdcard/08_search_cleared.png
    & $adb -s $DeviceSerial pull /sdcard/08_search_cleared.png "$artifactDir\08_search_cleared.png" | Out-Null

    # Búsqueda 4: Último resultado localizable (ej: 'Spider-Man' o 'Transformers' o 'Zootopia')
    Write-Output "Buscando título del catálogo ('Spider')..."
    & $adb -s $DeviceSerial shell input tap 400 210
    Start-Sleep -Milliseconds 300
    & $adb -s $DeviceSerial shell input text "Spider"
    Start-Sleep -Seconds 2
    & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
    Start-Sleep -Milliseconds 500
    & $adb -s $DeviceSerial shell screencap -p /sdcard/09_search_last_item.png
    & $adb -s $DeviceSerial pull /sdcard/09_search_last_item.png "$artifactDir\09_search_last_item.png" | Out-Null

    # ---------------------------------------------------------
    # 4. MEDICIÓN DE LATENCIA (MEDIANA Y P95) DE MODALES Y BÚSQUEDA
    # ---------------------------------------------------------
    Write-Output "`n[4/5] Midiendo latencia de apertura de Tipo y Género..."
    & $adb -s $DeviceSerial logcat -c

    # Probar abrir modal Tipo (x=270, y=360) 5 veces
    for ($m = 1; $m -le 5; $m++) {
        Write-Output "Apertura modal Tipo ($m/5)..."
        & $adb -s $DeviceSerial shell input tap 270 360
        Start-Sleep -Milliseconds 1200
        # Cerrar modal
        & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
        Start-Sleep -Milliseconds 800
    }

    # Probar abrir modal Género (x=810, y=360) 5 veces
    for ($m = 1; $m -le 5; $m++) {
        Write-Output "Apertura modal Género ($m/5)..."
        & $adb -s $DeviceSerial shell input tap 810 360
        Start-Sleep -Milliseconds 1200
        # Cerrar modal
        & $adb -s $DeviceSerial shell input keyevent KEYCODE_BACK
        Start-Sleep -Milliseconds 800
    }

    $modalLogs = & $adb -s $DeviceSerial logcat -d -s "flutter" | Select-String -Pattern "\[PERF_MODAL\] SHEET_RENDERED"
    $modalLogs | Out-File "$artifactDir\modal_latency_logs.txt" -Encoding utf8
    Write-Output "Logs de modales extraídos:"
    Write-Output $modalLogs

    # ---------------------------------------------------------
    # 5. GFXINFO Y FRAMES JANK
    # ---------------------------------------------------------
    Write-Output "`n[5/5] Midiendo Jank de Renderizado con dumpsys gfxinfo..."
    # Volver a Inicio: x=108, y=2125
    & $adb -s $DeviceSerial shell input tap 108 2125
    Start-Sleep -Seconds 2

    & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg reset | Out-Null
    Start-Sleep -Milliseconds 500

    # 10 swipes verticales continuos
    for ($s = 0; $s -lt 5; $s++) {
        & $adb -s $DeviceSerial shell input swipe 540 1800 540 600 200
        Start-Sleep -Milliseconds 250
        & $adb -s $DeviceSerial shell input swipe 540 600 540 1800 200
        Start-Sleep -Milliseconds 250
    }

    $gfxOutput = & $adb -s $DeviceSerial shell dumpsys gfxinfo $pkg
    $gfxOutput | Out-File "$artifactDir\dumpsys_gfxinfo.txt" -Encoding utf8
    Write-Output "dumpsys gfxinfo guardado en $artifactDir\dumpsys_gfxinfo.txt"

    # Screenshot final de inicio
    & $adb -s $DeviceSerial shell screencap -p /sdcard/10_home_after_scroll.png
    & $adb -s $DeviceSerial pull /sdcard/10_home_after_scroll.png "$artifactDir\10_home_after_scroll.png" | Out-Null

    Write-Output "`n¡AUDITORÍA FÍSICA FINALIZADA CON ÉXITO!"
}
finally {
    Write-Output "`n=================================================="
    Write-Output "RESTAURANDO ESTADO ORIGINAL DEL DISPOSITIVO (FINALLY)..."
    Write-Output "=================================================="
    & $adb -s $DeviceSerial shell wm size reset
    & $adb -s $DeviceSerial shell wm density reset
    & $adb -s $DeviceSerial shell settings put system accelerometer_rotation 1
    & $adb -s $DeviceSerial shell settings put system user_rotation 0
    & $adb -s $DeviceSerial shell svc wifi enable
    
    $finalWmSize = & $adb -s $DeviceSerial shell wm size
    $finalWmDensity = & $adb -s $DeviceSerial shell wm density
    $finalWifi = & $adb -s $DeviceSerial shell settings get global wifi_on
    Write-Output "Estado Final Restaurado: $finalWmSize | $finalWmDensity | Wi-Fi: $finalWifi"
}
