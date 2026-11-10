<#
  Chay toan bo he thong local (SQL Server trong Docker + API + gateway + web) chi bang 1 lenh.
  Dung:  pwsh -File scripts/run-local.ps1 [-SkipImport] [-Stop]
  Truyen -SqlServer neu muon dung SQL Server cai truc tiep tren may.
#>
[CmdletBinding()]
param([switch]$Stop, [switch]$SkipImport, [string]$SqlServer)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$work = Join-Path $root 'artifacts/local-learning'
$dockerSql = -not $PSBoundParameters.ContainsKey('SqlServer')
# Luon goi lai chinh PowerShell 7 dang chay (khong phu thuoc lenh 'pwsh' co trong PATH hay khong).
$pwsh = (Get-Process -Id $PID).Path
function Step($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m) { Write-Host "    OK  $m" -ForegroundColor Green }
function Need($cmd, $hint) {
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Thieu '$cmd'. $hint" }
    Ok $cmd
}

if ($Stop) {
    Step 'Dung backend'
    try { & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'start-local-ai.ps1') -Stop } catch {}
    & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'start-local-learning.ps1') -Stop
    & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'start-c2-test-infrastructure.ps1') -Stop -Sql:$dockerSql
    return
}

Step '1/8 Kiem tra cong cu'
Need dotnet 'Cai .NET 8 SDK: winget install Microsoft.DotNet.SDK.8'
Need node   'Cai Node.js: winget install OpenJS.NodeJS.LTS'
Need npm    'Cai Node.js: winget install OpenJS.NodeJS.LTS'
Need python 'Cai Python: winget install Python.Python.3.12 (nho tick Add to PATH)'
Need docker 'Cai Docker Desktop: winget install Docker.DockerDesktop'
docker info *> $null
if ($LASTEXITCODE) { throw 'Docker Desktop chua chay. Hay mo Docker Desktop, doi no bao "Engine running" roi chay lai.' }
Ok 'Docker dang chay'

Step '2/8 Tim SQL Server'
if ($dockerSql) {
    & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'start-local-learning.ps1') -InitOnly -DockerSql
    if ($LASTEXITCODE) { throw 'Khong tao duoc runtime local.' }
    $runtime = Get-Content (Join-Path $work 'runtime.json') -Raw | ConvertFrom-Json
    if (!$runtime.sqlPassword) { throw 'Runtime thieu mat khau SQL Docker.' }
    $SqlServer = '127.0.0.1,11433'
    Ok 'SQL Server se chay trong Docker, chi mo tai 127.0.0.1:11433'
}
elseif (!$SqlServer) {
    $services = @(Get-Service -Name 'MSSQLSERVER', 'MSSQL$*' -ErrorAction SilentlyContinue)
    if (!$services.Count) {
        throw ('Khong thay SQL Server tren may. Cai SQL Server Express roi chay lai: ' +
            'winget install Microsoft.SQLServer.2022.Express   (hoac tai tu microsoft.com/sql-server/sql-server-downloads)')
    }
    $svc = $services | Where-Object Status -eq 'Running' | Select-Object -First 1
    if (!$svc) {
        $svc = $services | Select-Object -First 1
        Write-Host "    Dich vu $($svc.Name) dang tat, thu bat..." -ForegroundColor Yellow
        try { Start-Service $svc.Name -ErrorAction Stop }
        catch {
            Write-Host '    Bat SQL Server can quyen quan tri. Hay bam YES o hop thoai UAC vua hien ra (co the nam duoi cac cua so khac / tren taskbar).' -ForegroundColor Yellow
            try { Start-Process -FilePath $pwsh -Verb RunAs -Wait -ArgumentList @('-NoProfile', '-Command', "Start-Service -Name '$($svc.Name)'") }
            catch { throw "Khong bat duoc $($svc.Name) (ban da tu choi UAC?). Hay mo Services (services.msc), bam chuot phai $($svc.Name) > Start, roi chay lai." }
        }
        for ($i = 0; $i -lt 20 -and (Get-Service $svc.Name).Status -ne 'Running'; $i++) { Start-Sleep -Seconds 1 }
        if ((Get-Service $svc.Name).Status -ne 'Running') { throw "Dich vu $($svc.Name) van chua chay. Mo Services (services.msc) va bam Start thu cong." }
    }
    $SqlServer = if ($svc.Name -eq 'MSSQLSERVER') { 'localhost' } else { '.\' + $svc.Name.Substring('MSSQL$'.Length) }
}
Ok "SQL Server = $SqlServer"

Step '3/8 Cai dotnet-ef va thu vien web'
$env:PATH += ";$env:USERPROFILE\.dotnet\tools"
python -c "import pymupdf; assert pymupdf.VersionBind == '2.0'" *> $null
if ($LASTEXITCODE) {
    python -m pip install 'pymupdf==2.0'
    if ($LASTEXITCODE) { throw 'Khong cai duoc PyMuPDF 2.0 de doi chieu PDF nguon.' }
}
Ok 'PyMuPDF 2.0'
dotnet ef --version *> $null
if ($LASTEXITCODE) {
    dotnet tool install --global dotnet-ef --version 8.*
    if ($LASTEXITCODE) { throw 'Khong cai duoc dotnet-ef.' }
}
Ok 'dotnet-ef'
if (!(Test-Path (Join-Path $root 'web/node_modules/vite/bin/vite.js'))) {
    npm --prefix web ci
    if ($LASTEXITCODE) { throw 'npm ci that bai.' }
}
Ok 'web/node_modules'

Step '4/8 Build (de tao database)'
dotnet build Presentation/Presentation.csproj --nologo -v quiet
if ($LASTEXITCODE) { throw 'Build Presentation that bai. Xem loi o tren.' }
Ok 'Presentation'

Step '5/8 Bat ha tang Docker (lan dau se tai image, co the lau)'
$oldSaPassword = $env:SA_PASSWORD
try {
    if ($dockerSql) { $env:SA_PASSWORD = $runtime.sqlPassword }
    & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'start-c2-test-infrastructure.ps1') -Ai -Sql:$dockerSql
} finally { $env:SA_PASSWORD = $oldSaPassword }
if ($LASTEXITCODE) { throw 'Khong bat duoc Redis/Kafka.' }
$ready = $false
for ($i = 0; $i -lt 40; $i++) {
    docker exec prn-c2-localtest-kafka-1 /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 3
}
if (!$ready) { throw 'Kafka chua san sang sau 2 phut. Kiem tra Docker Desktop.' }
Ok 'SQL + Redis + Kafka + Qdrant'

Step '6/8 Tao database va chay API + gateway + web'
$launcher = Join-Path $PSScriptRoot 'start-local-learning.ps1'
$alreadyUp = $false
try { $alreadyUp = (Invoke-WebRequest 'http://127.0.0.1:18080/health/live' -TimeoutSec 2 -UseBasicParsing).StatusCode -eq 200 } catch {}
if ($alreadyUp) {
    $localRuntime = Get-Content (Join-Path $work 'runtime.json') -Raw | ConvertFrom-Json
    $loginBody = @{ email = $localRuntime.adminEmail; password = $localRuntime.adminPassword } | ConvertTo-Json
    $loginReady = $false
    try {
        $loginReady = (Invoke-WebRequest ($localRuntime.user + '/api/auth/login') -Method Post `
            -ContentType 'application/json' -Body $loginBody -TimeoutSec 10 -UseBasicParsing).StatusCode -eq 200
    } catch {}
    if (!$loginReady) {
        if (!(Test-Path (Join-Path $work 'processes.json'))) {
            throw 'Backend dang chay nhung khong thuoc launcher local; khong the cap nhat tai khoan demo.'
        }
        & $pwsh -NoProfile -File $launcher -Stop
        if ($LASTEXITCODE) { throw 'Khong dung duoc backend local cu de cap nhat tai khoan demo.' }
        $alreadyUp = $false
    }
}
if ($alreadyUp) {
    Ok 'Backend da chay san, bo qua'
} else {
    if (!$dockerSql) {
        & $pwsh -NoProfile -File $launcher -InitOnly -SqlServer $SqlServer
        if ($LASTEXITCODE) { throw 'Khoi tao runtime that bai.' }
    }
    $hasAiVenv = Test-Path (Join-Path $root 'artifacts/c2-python/.venv/Scripts/python.exe')
    $enableAi = $false
    if ($hasAiVenv) {
        try {
            & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'start-local-ai.ps1')
            if ($LASTEXITCODE -eq 0) { $enableAi = $true; Ok 'AI gRPC service dang chay (127.0.0.1:15051)' }
        } catch {
            Write-Host '    Bo qua AI (chua bat duoc AI service).' -ForegroundColor Yellow
        }
    }
    & $pwsh -NoProfile -File $launcher -SqlServer $SqlServer -DockerSql:$dockerSql -EnableAi:$enableAi
    if ($LASTEXITCODE) { throw "Khoi dong backend that bai. Xem log trong $work" }
    Ok 'Backend dang chay'
}

Step '7/8 Nap bo cau hoi va de thi local'
if ($SkipImport) { Write-Host '    Bo qua (-SkipImport)' }
else {
    if (!(Test-Path (Join-Path $work 'import-result.json'))) {
        & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'import-local-learning.ps1')
        if ($LASTEXITCODE) { throw 'Khong nap duoc 115 cau sa hinh.' }
    }
    if (!(Test-Path (Join-Path $root 'artifacts/question-bank-600/import-result.json'))) {
        & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'prepare-question-bank-600.ps1')
        if ($LASTEXITCODE) { throw 'Khong kiem tra duoc nguon 600 cau.' }
        & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'import-question-bank-600.ps1')
        if ($LASTEXITCODE) { throw 'Khong nap duoc bo 600 cau.' }
    }
    if (!(Test-Path (Join-Path $root 'artifacts/official-profile/import-result.json'))) {
        & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'import-question-bank-600.ps1') -OfficialB
        if ($LASTEXITCODE) { throw 'Khong nap duoc bo thi thu hang B.' }
    }
    Ok '115 cau sa hinh, 600 cau on tap, 600 cau thi thu B da san sang'
}

Step '8/8 Xong'
$rt = Get-Content (Join-Path $work 'runtime.json') -Raw | ConvertFrom-Json
$info = @(
    "Web:       $($rt.web)",
    "Email:     $($rt.adminEmail)",
    "Mat khau:  $($rt.adminPassword)",
    "Tat he thong: pwsh -File scripts/run-local.ps1 -Stop"
)
$info | Set-Content (Join-Path $work 'DANG-NHAP.txt') -Encoding utf8
Write-Host "    Web: $($rt.web)" -ForegroundColor Green
Write-Host "    Thong tin dang nhap: $work/DANG-NHAP.txt" -ForegroundColor Green
Start-Process $rt.web
