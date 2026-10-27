# Lanza la app apuntando al proyecto de Supabase de env/dev.json.
#
# Existe porque Flutter no admite argumentos por defecto a nivel de proyecto:
# sin esto habria que acordarse del --dart-define-from-file en cada arranque,
# y olvidarlo da una app con la agenda de muestra que parece real.
#
#   .\run.ps1              -> Chrome en el puerto 5000
#   .\run.ps1 windows      -> escritorio
#   .\run.ps1 chrome 8080  -> otro puerto

param(
    [string]$Device = "chrome",
    [int]$Port = 5000
)

$config = "env/dev.json"

if (-not (Test-Path $config)) {
    Write-Host "Falta $config. Copia env/example.json y pon tus claves." -ForegroundColor Red
    Write-Host "Las encuentras en el panel de Supabase, en Settings -> API."
    exit 1
}

$valores = Get-Content $config -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($valores.SUPABASE_URL)) {
    Write-Host "$config no tiene SUPABASE_URL." -ForegroundColor Yellow
    Write-Host "La app arrancara con la agenda de muestra, no con la real."
}

$argumentos = @("run", "-d", $Device, "--dart-define-from-file=$config")

# --web-port solo lo entienden los dispositivos web.
if ($Device -in @("chrome", "edge", "web-server")) {
    $argumentos += @("--web-port", $Port)
}

Write-Host "flutter $($argumentos -join ' ')" -ForegroundColor DarkGray
& flutter @argumentos
