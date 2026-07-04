$c = Get-Content "C:\Users\Kleiner\proyectos\mi_app\lib\screens\settings_screen.dart" -Raw
$c = $c -replace "Icons\.pause_on_missing_data", "Icons.play_disabled"
$c = $c -replace "import '../services/storage_service\.dart';\r?\n", ""
[System.IO.File]::WriteAllText("C:\Users\Kleiner\proyectos\mi_app\lib\screens\settings_screen.dart", $c, [System.Text.Encoding]::UTF8)
Write-Host "settings_screen.dart fixed"