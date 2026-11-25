# Corre todas las pruebas automáticas sin ventana y dice cuáles fallaron.
# Uso (PowerShell, desde la carpeta del proyecto):
#   .\tests\probar_todo.ps1
#   .\tests\probar_todo.ps1 -Godot "C:\ruta\Godot_v4.7.2-stable_win64_console.exe"
# Si no pasas -Godot, usa la variable de entorno GODOT o "godot" del PATH.
param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }),
    [int]$LimiteSeg = 900   # una prueba que tarde más se da por fallida (la auditoría tarda unos 5 min)
)

$proyecto = Split-Path -Parent $PSScriptRoot
$pruebas = @("auditoria", "gps", "sismo")
$fallidas = @()
$tmp = [System.IO.Path]::GetTempPath()

function Invoke-Godot([string[]]$argumentos, [string]$salida) {
    $p = Start-Process -FilePath $Godot -ArgumentList $argumentos -NoNewWindow -PassThru `
        -RedirectStandardOutput $salida -RedirectStandardError "$salida.err"
    $null = $p.Handle   # sin esto, PowerShell 5.1 no guarda el código de salida
    if (-not $p.WaitForExit($LimiteSeg * 1000)) {
        Stop-Process -Id $p.Id -Force
        return -1
    }
    return $p.ExitCode
}

# Registra las clases nuevas (class_name) aunque no se haya abierto el editor
Write-Host "== Actualizando la caché de clases" -ForegroundColor Cyan
$null = Invoke-Godot @("--headless", "--path", "`"$proyecto`"", "--import") (Join-Path $tmp "rs_import.log")

foreach ($p in $pruebas) {
    Write-Host "== $p" -ForegroundColor Cyan
    $log = Join-Path $tmp "rs_$p.log"
    $codigo = Invoke-Godot @("--headless", "--path", "`"$proyecto`"", "res://tests/$p.tscn") $log
    Get-Content $log, "$log.err" -ErrorAction SilentlyContinue |
        Select-String -Pattern "Errores:|fallos|SCRIPT ERROR|Parse Error|^ERROR: [A-Z][a-z]" |
        ForEach-Object { Write-Host "   $_" }
    if ($codigo -eq -1) { Write-Host "   Se pasó de $LimiteSeg s: se detuvo" -ForegroundColor Red }
    if ($codigo -ne 0) { $fallidas += $p }
}

if ($fallidas.Count -eq 0) {
    Write-Host "Todas las pruebas pasaron." -ForegroundColor Green
    exit 0
}
Write-Host ("Fallaron: " + ($fallidas -join ", ")) -ForegroundColor Red
exit 1
