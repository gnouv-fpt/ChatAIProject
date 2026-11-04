[CmdletBinding()]
param([switch]$Stop, [switch]$SkipBuild, [switch]$EnableAi, [switch]$InitOnly,
    [switch]$DockerSql, [string]$SqlServer = '.\MSSQLSERVER_VUON')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root 'artifacts/local-learning'
[void][IO.Directory]::CreateDirectory($work)
$runtimePath = Join-Path $work 'runtime.json'
$processPath = Join-Path $work 'processes.json'
if ($Stop) {
    if (Test-Path -LiteralPath $processPath) {
        $saved = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
        foreach ($item in $saved) {
            $process = Get-CimInstance Win32_Process -Filter "ProcessId = $($item.id)" -ErrorAction SilentlyContinue
            if ($process -and $process.CommandLine.Contains($item.marker)) { Stop-Process -Id $item.id }
        }
    }
    Write-Host 'Stopped only processes recorded by this local-learning launcher; databases and Redis remain.'
    return
}
if (!$InitOnly -and (Test-Path -LiteralPath $processPath)) {
    $saved = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
    if ($saved | Where-Object { Get-Process -Id $_.id -ErrorAction SilentlyContinue }) {
        throw 'Local-learning processes are already recorded as running. Use -Stop before restarting.'
    }
}
if (!(Test-Path -LiteralPath $runtimePath)) {
    $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $runtime = [ordered]@{
        userDatabase = "TrafficUser_WebLearning_$suffix"; contentDatabase = "TrafficContent_WebLearning_$suffix"
        jwt = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        sqlPassword = 'C2a!' + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(20))
        adminEmail = 'admin@local-learning.test'; adminPassword = 'Local@' + [Guid]::NewGuid().ToString('N')
        gateway = 'http://127.0.0.1:18080'; user = 'http://127.0.0.1:15039'; content = 'http://127.0.0.1:15040'
        web = 'http://127.0.0.1:15173'; assets = 'http://localhost:8765'
    }
    $runtime | ConvertTo-Json | Set-Content -LiteralPath $runtimePath -Encoding utf8
}
$runtime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json
$requestedSqlMode = if ($DockerSql) { 'docker' } else { 'host' }
if (!$runtime.sqlMode) {
    $runtime | Add-Member -NotePropertyName sqlMode -NotePropertyValue $requestedSqlMode
    $runtime | ConvertTo-Json | Set-Content -LiteralPath $runtimePath -Encoding utf8
} elseif ($runtime.sqlMode -ne $requestedSqlMode) {
    throw 'This isolated runtime already uses a different SQL mode.'
}
if ($DockerSql -and !$runtime.sqlPassword) {
    $runtime | Add-Member -NotePropertyName sqlPassword -NotePropertyValue ('C2a!' +
        [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(20)))
    $runtime | ConvertTo-Json | Set-Content -LiteralPath $runtimePath -Encoding utf8
}
if ($runtime.gateway -ne 'http://127.0.0.1:18080' -or $runtime.user -ne 'http://127.0.0.1:15039' -or
    $runtime.content -ne 'http://127.0.0.1:15040' -or $runtime.web -ne 'http://127.0.0.1:15173' -or $runtime.assets -ne 'http://localhost:8765') {
    throw 'Unexpected local endpoint configuration.'
}
foreach ($name in @($runtime.userDatabase, $runtime.contentDatabase)) {
    if ($name -notmatch '^Traffic(User|Content)_WebLearning_[a-f0-9]{8}$') { throw 'Unexpected local database target.' }
}
if ($runtime.userDatabase.Substring('TrafficUser_WebLearning_'.Length) -ne
    $runtime.contentDatabase.Substring('TrafficContent_WebLearning_'.Length)) {
    throw 'User and Content databases must share one isolated runtime suffix.'
}
if ($InitOnly) {
    Write-Host 'Isolated local-learning runtime initialized; hosts and databases were not started.'
    return
}
foreach ($port in @(15039,15040,15173,18080)) {
    if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) { throw "Local port $port is already occupied; no existing process was stopped." }
}
Push-Location $root
try {
    python scripts/build-local-learning-bank.py --asset-origin $runtime.assets --output (Join-Path $work 'package.json')
    if ($LASTEXITCODE) { throw 'Bank preparation failed.' }
    if (!$SkipBuild) {
        foreach ($project in @('Presentation','ApiGateway','WorkerService')) {
            dotnet build "$project/$project.csproj" --nologo -v quiet -o (Join-Path $work "bin/$project")
            if ($LASTEXITCODE) { throw "Build failed: $project" }
        }
    }
    foreach ($topic in @('local-learning-exam-submitted-v1','local-learning-exam-submitted-dlq-v1')) {
        docker exec prn-c2-localtest-kafka-1 /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --if-not-exists --topic $topic --partitions 3 --replication-factor 1
        if ($LASTEXITCODE) { throw 'Local Kafka infrastructure is unavailable. Start scripts/start-c2-test-infrastructure.ps1 first.' }
    }
    $common = @{
        ASPNETCORE_ENVIRONMENT = 'Development'; DOTNET_ENVIRONMENT = 'Development'
        Jwt__SecretKey = $runtime.jwt
        ConnectionStrings__UserConnection = $(if ($DockerSql) {
            "Server=$SqlServer;Database=$($runtime.userDatabase);User Id=sa;Password=$($runtime.sqlPassword);Encrypt=True;TrustServerCertificate=True"
        } else {
            "Server=$SqlServer;Database=$($runtime.userDatabase);Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False"
        })
        ConnectionStrings__ContentConnection = $(if ($DockerSql) {
            "Server=$SqlServer;Database=$($runtime.contentDatabase);User Id=sa;Password=$($runtime.sqlPassword);Encrypt=True;TrustServerCertificate=True"
        } else {
            "Server=$SqlServer;Database=$($runtime.contentDatabase);Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False"
        })
        ConnectionStrings__Redis = 'localhost:16379,defaultDatabase=3'
        Content__LocalAssetOrigin = $runtime.assets
        GrpcService__Address = $(if ($EnableAi) { 'http://127.0.0.1:15051' } else { 'http://localhost:50051' })
        Content__EnableVerifiedIndexing = $EnableAi.ToString().ToLowerInvariant()
        ContentService__Address = $runtime.content + '/'; Exams__ContentBaseUrl = $runtime.content + '/'; Exams__UserBaseUrl = $runtime.user + '/'
        Exams__Kafka__BootstrapServers = 'localhost:19092'; Exams__Kafka__Topic = 'local-learning-exam-submitted-v1'
        Exams__Kafka__DeadLetterTopic = 'local-learning-exam-submitted-dlq-v1'; Exams__Kafka__GroupId = 'local-learning-notifications-v1'
        Auth__SeedAdmin__Email = $runtime.adminEmail; Auth__SeedAdmin__Password = $runtime.adminPassword
        Auth__SeedAdminOnStartup = 'false'; Database__MigrateOnStartup = 'false'; Jobs__EnableLegacyMidnight = 'false'
    }
    $old = @{}
    foreach ($key in $common.Keys) { $old[$key] = [Environment]::GetEnvironmentVariable($key); [Environment]::SetEnvironmentVariable($key, $common[$key]) }
    try {
        # Apply only the existing migrations, explicitly, to this task's isolated databases.
        foreach ($context in @('UserDbContext','ContentDbContext')) {
            dotnet ef database update --context $context --project DataAccess --startup-project Presentation --no-build
            if ($LASTEXITCODE) { throw "Local database setup failed: $context" }
        }
        $started = [Collections.Generic.List[object]]::new()
        function Start-HostProcess($name, $file, $arguments, $directory, $extra, $marker) {
            $previous = @{}
            foreach ($key in $extra.Keys) { $previous[$key] = [Environment]::GetEnvironmentVariable($key); [Environment]::SetEnvironmentVariable($key, $extra[$key]) }
            try {
                $process = Start-Process -FilePath $file -ArgumentList $arguments -WorkingDirectory $directory -WindowStyle Hidden -PassThru `
                    -RedirectStandardOutput (Join-Path $work "$name.stdout.log") -RedirectStandardError (Join-Path $work "$name.stderr.log")
                $started.Add(@{ id = $process.Id; name = $name; marker = $marker })
                $started | ConvertTo-Json -AsArray | Set-Content -LiteralPath $processPath -Encoding utf8
            } finally { foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key]) } }
        }
        if (!(Get-NetTCPConnection -State Listen -LocalPort 8765 -ErrorAction SilentlyContinue)) {
            $server = Join-Path $root 'scripts/serve-animation-review.py'
            Start-HostProcess 'assets' 'python' @($server) $root @{} $server
        }
        $presentation = Join-Path $work 'bin/Presentation/Presentation.dll'
        Start-HostProcess 'content' 'dotnet' @($presentation,'--urls',$runtime.content) (Join-Path $root 'Presentation') @{ Service__Module = 'Content' } $presentation
        Start-HostProcess 'user' 'dotnet' @($presentation,'--urls',$runtime.user) (Join-Path $root 'Presentation') @{ Service__Module = 'User'; Auth__SeedAdminOnStartup = 'true' } $presentation
        $gateway = Join-Path $work 'bin/ApiGateway/ApiGateway.dll'
        Start-HostProcess 'gateway' 'dotnet' @($gateway,'--urls',$runtime.gateway) (Join-Path $root 'ApiGateway') @{
            ReverseProxy__Clusters__user__Destinations__user__Address = $runtime.user + '/'
            ReverseProxy__Clusters__content__Destinations__content__Address = $runtime.content + '/'
            ReverseProxy__Clusters__web__Destinations__web__Address = $runtime.web + '/'
        } $gateway
        $worker = Join-Path $work 'bin/WorkerService/WorkerService.dll'
        Start-HostProcess 'worker' 'dotnet' @($worker) (Join-Path $root 'WorkerService') @{} $worker
        $vite = Join-Path $root 'web/node_modules/vite/bin/vite.js'
        Start-HostProcess 'web' 'node' @($vite,'--host','127.0.0.1','--port','15173','--strictPort') (Join-Path $root 'web') @{
            C2_GATEWAY_URL = $runtime.gateway; C2_USER_URL = $runtime.user
        } $vite
    } finally { foreach ($key in $old.Keys) { [Environment]::SetEnvironmentVariable($key, $old[$key]) } }
    foreach ($url in @(($runtime.user + '/health/ready'), ($runtime.content + '/health/ready'),
            ($runtime.gateway + '/health/live'), ($runtime.web + '/'))) {
        $ready = $false; $deadline = (Get-Date).AddSeconds(40)
        while ((Get-Date) -lt $deadline) {
            try { $ready = (Invoke-WebRequest $url -TimeoutSec 2 -UseBasicParsing).StatusCode -eq 200 } catch { $ready = $false }
            if ($ready) { break }
            Start-Sleep -Milliseconds 400
        }
        if (!$ready) { throw "Local host did not become ready: $url. Inspect logs under artifacts/local-learning." }
    }
    Write-Host "Local learning ready at $($runtime.gateway). Credentials are stored only in the ignored runtime file."
} finally { Pop-Location }
