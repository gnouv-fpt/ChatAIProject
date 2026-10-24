param([ValidateSet('api','gateway','web')][string]$Service = 'api')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
switch ($Service) {
    'api' { dotnet run --project Presentation --launch-profile http }
    'gateway' { $env:ASPNETCORE_URLS = 'http://127.0.0.1:5080'; dotnet run --project ApiGateway --no-launch-profile }
    'web' { Set-Location -LiteralPath (Join-Path $repoRoot 'web'); npm run dev }
}
