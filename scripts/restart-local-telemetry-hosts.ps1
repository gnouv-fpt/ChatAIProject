[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root 'artifacts/local-learning'
$runtime = Get-Content -LiteralPath (Join-Path $work 'runtime.json') -Raw | ConvertFrom-Json
$recordPath = Join-Path $work 'processes.json'
$records = @(Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json)
if ($runtime.gateway -ne 'http://127.0.0.1:18080' -or $runtime.user -ne 'http://127.0.0.1:15039' -or
    $runtime.content -ne 'http://127.0.0.1:15040' -or $runtime.contentDatabase -ne 'TrafficContent_WebLearning_57e824ae') {
    throw 'Unexpected local-learning stack; no processes stopped.'
}
$observed = Join-Path $root ('artifacts/local-monitoring/bin-' + [guid]::NewGuid().ToString('N'))
foreach ($name in @('Presentation','ApiGateway')) {
    dotnet publish (Join-Path $root "$name/$name.csproj") -c Debug -o (Join-Path $observed $name) --no-restore -v:q
    if ($LASTEXITCODE) { throw "Build failed for $name; no processes stopped." }
}
foreach ($name in @('gateway','user','content')) {
    $entry = $records | Where-Object name -EQ $name | Select-Object -First 1
    if (!$entry) { throw "Missing recorded process $name; no processes stopped." }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $($entry.id)" -ErrorAction SilentlyContinue
    if ($process -and !$process.CommandLine.Contains($entry.marker)) {
        throw "Recorded PID for $name belongs to another process; no processes stopped."
    }
}
$common = @{
    ASPNETCORE_ENVIRONMENT = 'Development'; DOTNET_ENVIRONMENT = 'Development'
    Jwt__SecretKey = $runtime.jwt
    ConnectionStrings__UserConnection = "Server=.\MSSQLSERVER_VUON;Database=$($runtime.userDatabase);Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False"
    ConnectionStrings__ContentConnection = "Server=.\MSSQLSERVER_VUON;Database=$($runtime.contentDatabase);Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False"
    ConnectionStrings__Redis = 'localhost:16379,defaultDatabase=3'
    GrpcService__Address = 'http://127.0.0.1:15051'
    Content__EnableVerifiedIndexing = 'true'
    Content__LocalAssetOrigin = $runtime.assets
    ContentService__Address = $runtime.content + '/'
    Exams__ContentBaseUrl = $runtime.content + '/'
    Exams__UserBaseUrl = $runtime.user + '/'
    Exams__Kafka__BootstrapServers = 'localhost:19092'
    Exams__Kafka__Topic = 'local-learning-exam-submitted-v1'
    Exams__Kafka__DeadLetterTopic = 'local-learning-exam-submitted-dlq-v1'
    Exams__Kafka__GroupId = 'local-learning-notifications-v1'
    Auth__SeedAdminOnStartup = 'false'
    Database__MigrateOnStartup = 'false'
    Jobs__EnableLegacyMidnight = 'false'
    OTEL_EXPORTER_OTLP_ENDPOINT = 'http://127.0.0.1:14317'
}
function Start-Observed($name, $dll, $directory, $url, $extra) {
    $settings = $common.Clone()
    foreach ($key in $extra.Keys) { $settings[$key] = $extra[$key] }
    $previous = @{}
    try {
        foreach ($key in $settings.Keys) {
            $previous[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $settings[$key])
        }
        $process = Start-Process -FilePath 'dotnet' -ArgumentList @($dll, '--urls', $url) -WorkingDirectory $directory `
            -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $work "observed-$name.stdout.log") `
            -RedirectStandardError (Join-Path $work "observed-$name.stderr.log")
        $entry = $records | Where-Object name -EQ $name | Select-Object -First 1
        $entry.id = $process.Id; $entry.marker = $dll
        $records | ConvertTo-Json -AsArray -Depth 5 | Set-Content -LiteralPath $recordPath -Encoding utf8
    } finally {
        foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key]) }
        $settings.Clear()
    }
}
foreach ($name in @('gateway','user','content')) {
    $entry = $records | Where-Object name -EQ $name | Select-Object -First 1
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $($entry.id)" -ErrorAction SilentlyContinue
    if ($process) { Stop-Process -Id $entry.id }
}
$presentation = Join-Path $observed 'Presentation/Presentation.dll'
$gateway = Join-Path $observed 'ApiGateway/ApiGateway.dll'
Start-Observed 'content' $presentation (Join-Path $root 'Presentation') $runtime.content @{
    Service__Module='Content'; Logging__FilePath=(Join-Path $root 'logs/content.jsonl')
}
Start-Observed 'user' $presentation (Join-Path $root 'Presentation') $runtime.user @{
    Service__Module='User'; Logging__FilePath=(Join-Path $root 'logs/user.jsonl')
}
Start-Observed 'gateway' $gateway (Join-Path $root 'ApiGateway') $runtime.gateway @{
    Logging__FilePath=(Join-Path $root 'logs/gateway-native.jsonl')
    ReverseProxy__Clusters__user__Destinations__user__Address=$runtime.user + '/'
    ReverseProxy__Clusters__content__Destinations__content__Address=$runtime.content + '/'
    ReverseProxy__Clusters__web__Destinations__web__Address=$runtime.web + '/'
}
foreach ($url in @(($runtime.user + '/health/ready'), ($runtime.content + '/health/ready'), ($runtime.gateway + '/health/live'))) {
    $ready = $false
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        try { $ready = (Invoke-WebRequest $url -TimeoutSec 2).StatusCode -eq 200 } catch { $ready = $false }
        if ($ready) { break }
        Start-Sleep -Milliseconds 400
    }
    if (!$ready) { throw "Local host not ready: $url. Inspect ignored observed logs." }
}
Write-Host 'Local Gateway, User and Content hosts are ready with Tempo export; databases were not migrated.'
