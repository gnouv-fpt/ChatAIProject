[CmdletBinding()]
param([switch]$Stop)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root 'artifacts/local-learning'
$runtime = Get-Content -LiteralPath (Join-Path $work 'runtime.json') -Raw | ConvertFrom-Json
$processPath = Join-Path $work 'monitoring-worker.json'
$dll = Join-Path $work 'bin/WorkerService/WorkerService.dll'
if ($runtime.gateway -ne 'http://127.0.0.1:18080' -or $runtime.user -ne 'http://127.0.0.1:15039' -or
    $runtime.content -ne 'http://127.0.0.1:15040') { throw 'Unexpected local-learning runtime.' }
if (Test-Path $processPath) {
    $saved = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
    $existing = Get-CimInstance Win32_Process -Filter "ProcessId = $($saved.id)" -ErrorAction SilentlyContinue
    if ($existing -and $existing.CommandLine.Contains($dll)) {
        if ($Stop) { Stop-Process -Id $saved.id; Write-Host 'Monitoring Worker stopped.'; return }
        throw 'Monitoring Worker is already running.'
    }
}
if ($Stop) { return }
if (!(Test-Path $dll)) { throw 'Publish WorkerService into the existing local-learning bin first.' }
if (Get-NetTCPConnection -State Listen -LocalPort 15042 -ErrorAction SilentlyContinue) {
    throw 'Monitoring Worker port is occupied.'
}
$settings = @{
    ASPNETCORE_ENVIRONMENT = 'Development'; DOTNET_ENVIRONMENT = 'Development'
    ASPNETCORE_URLS = 'http://127.0.0.1:15042'; Jwt__SecretKey = $runtime.jwt
    ConnectionStrings__Redis = 'localhost:16379,defaultDatabase=3'
    Exams__Kafka__BootstrapServers = 'localhost:19092'
    Exams__Kafka__Topic = 'local-learning-exam-submitted-v1'
    Exams__Kafka__DeadLetterTopic = 'local-learning-exam-submitted-dlq-v1'
    Exams__Kafka__GroupId = 'local-learning-notifications-v1'
    Exams__ContentBaseUrl = $runtime.content + '/'; Exams__UserBaseUrl = $runtime.user + '/'
    ContentService__Address = $runtime.content + '/'
    Logging__FilePath = (Join-Path $root 'logs/worker.jsonl')
    OTEL_EXPORTER_OTLP_ENDPOINT = 'http://127.0.0.1:14317'
}
$previous = @{}
try {
    foreach ($name in $settings.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name)
        [Environment]::SetEnvironmentVariable($name, $settings[$name])
    }
    $process = Start-Process -FilePath 'dotnet' -ArgumentList @($dll) -WorkingDirectory (Join-Path $root 'WorkerService') `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $work 'monitoring-worker.stdout.log') `
        -RedirectStandardError (Join-Path $work 'monitoring-worker.stderr.log')
    @{ id = $process.Id; marker = $dll } | ConvertTo-Json | Set-Content -LiteralPath $processPath -Encoding utf8
} finally {
    foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name]) }
    $settings.Clear()
}
$deadline = (Get-Date).AddSeconds(15)
while ((Get-Date) -lt $deadline) {
    if ($process.HasExited) { throw 'Monitoring Worker exited; inspect the ignored local log.' }
    try {
        if ((Invoke-WebRequest 'http://127.0.0.1:15042/metrics' -TimeoutSec 2).StatusCode -eq 200) {
            Write-Host 'Monitoring Worker metrics ready on 127.0.0.1:15042.'
            return
        }
    } catch { }
    Start-Sleep -Milliseconds 400
}
throw 'Monitoring Worker metrics did not become ready.'
