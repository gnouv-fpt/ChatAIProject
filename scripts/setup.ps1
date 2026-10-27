# Chuan bi moi truong local cho REST API service: user-secrets + build.
# Chay 1 lan sau khi pull/clone repo:
#   pwsh -File scripts/setup.ps1
# (hoac chuot phai > Run with PowerShell)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$presentation = Join-Path $root "Presentation"

Write-Host "==> Kiem tra .NET SDK" -ForegroundColor Cyan
dotnet --version | Out-Null

Write-Host "==> Restore packages" -ForegroundColor Cyan
dotnet restore (Join-Path $root "ChatAIWeb.slnx")

function Get-ExistingSecret([string]$key) {
    $list = dotnet user-secrets list --project $presentation 2>$null
    $line = $list | Where-Object { $_ -like "$key = *" }
    if ($line) { return $true }
    return $false
}

Write-Host "==> Cau hinh user-secrets (Jwt:SecretKey, tai khoan admin mac dinh)" -ForegroundColor Cyan

if (-not (Get-ExistingSecret "Jwt:SecretKey")) {
    $bytes = New-Object byte[] 48
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $randomKey = [Convert]::ToBase64String($bytes)
    dotnet user-secrets set "Jwt:SecretKey" $randomKey --project $presentation | Out-Null
    Write-Host "   - Da tao Jwt:SecretKey ngau nhien cho may nay." -ForegroundColor Green
} else {
    Write-Host "   - Jwt:SecretKey da ton tai, giu nguyen." -ForegroundColor DarkGray
}

if (-not (Get-ExistingSecret "Auth:SeedAdmin:Email")) {
    dotnet user-secrets set "Auth:SeedAdmin:Email" "admin@chataiweb.local" --project $presentation | Out-Null
    dotnet user-secrets set "Auth:SeedAdmin:Password" "Admin@123456" --project $presentation | Out-Null
    Write-Host "   - Tai khoan admin mac dinh: admin@chataiweb.local / Admin@123456" -ForegroundColor Green
} else {
    Write-Host "   - Auth:SeedAdmin da cau hinh, giu nguyen." -ForegroundColor DarkGray
}

Write-Host "==> Build solution" -ForegroundColor Cyan
dotnet build (Join-Path $root "ChatAIWeb.slnx")

Write-Host ""
Write-Host "Xong! Chua apply migrations. Xem docs/C2-SCHEMA-CONTRACT.md cho hai SQL DB." -ForegroundColor Green
Write-Host "Chay API:" -ForegroundColor Cyan
Write-Host "  dotnet run --project Presentation --launch-profile http"
Write-Host "Swagger: http://localhost:5039/swagger"
Write-Host ""
Write-Host "Cau hinh UserConnection va ContentConnection; chay them profile content tren port 5040." -ForegroundColor Yellow
Write-Host "Sau khi apply schema, co the seed admin bang --Auth:SeedAdminOnStartup true tren User host." -ForegroundColor Yellow
Write-Host "(mac dinh dung SQL Server local, Windows Authentication)." -ForegroundColor Yellow
