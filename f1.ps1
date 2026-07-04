$content = Get-Content "C:\Users\Kleiner\proyectos\mi_app\lib\theme\app_theme.dart" -Raw
$content = $content -replace 'CardTheme\(', 'CardThemeData('
[System.IO.File]::WriteAllText("C:\Users\Kleiner\proyectos\mi_app\lib\theme\app_theme.dart", $content, [System.Text.Encoding]::UTF8)
Write-Host "app_theme.dart fixed: CardTheme -> CardThemeData"