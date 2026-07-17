$c = Get-Content "C:\Users\Kleiner\proyectos\mi_app\lib\screens\lists_screen.dart" -Raw
$c = $c -replace "import '../services/m3u_parser_service\.dart';\r?\n", ""
[System.IO.File]::WriteAllText("C:\Users\Kleiner\proyectos\mi_app\lib\screens\lists_screen.dart", $c, [System.Text.Encoding]::UTF8)
Write-Host "lists_screen.dart fixed"