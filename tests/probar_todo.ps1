# Corre todas las pruebas automáticas sin ventana y dice cuáles fallaron.
# Uso (PowerShell, desde la carpeta del proyecto):
#   .\tests\probar_todo.ps1
#   .\tests\probar_todo.ps1 -Godot "C:\ruta\Godot_v4.7.2-stable_win64_console.exe"
# Si no pasas -Godot, usa la variable de entorno GODOT o "godot" del PATH.
param([string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }))

$proyecto = Split-Path -Parent $PSScriptRoot
$pruebas = @("auditoria", "gps", "sismo")
$fallidas = @()

foreach ($p in $pruebas) {
    Write-Host "== $p" -ForegroundColor Cyan
    & $Godot --headless --path $proyecto "res://tests/$p.tscn" 2>&1 |
        Select-String -Pattern "Errores:|fallos|SCRIPT ERROR|Parse Error|^ERROR: [A-Z][a-z]" |
        ForEach-Object { Write-Host "   $_" }
    if ($LASTEXITCODE -ne 0) { $fallidas += $p }
}

if ($fallidas.Count -eq 0) {
    Write-Host "Todas las pruebas pasaron." -ForegroundColor Green
    exit 0
}
Write-Host ("Fallaron: " + ($fallidas -join ", ")) -ForegroundColor Red
exit 1
