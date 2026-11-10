[CmdletBinding()]
param([switch]$Stop, [ValidateSet('auto','groq','gemini')][string]$GenerationProvider = 'auto')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root 'artifacts/local-ai'
[void][IO.Directory]::CreateDirectory($work)
$processPath = Join-Path $work 'process.json'
$server = Join-Path $root 'grpc_inference_service/server.py'
if (Test-Path -LiteralPath $processPath) {
    $record = Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $($record.id)" -ErrorAction SilentlyContinue
    if ($process -and $process.CommandLine.Contains($server)) {
        if ($Stop) { Stop-Process -Id $record.id; return }
        throw 'The recorded local AI process is already running.'
    }
}
if ($Stop) { return }
if (Get-NetTCPConnection -State Listen -LocalPort 15051 -ErrorAction SilentlyContinue) { throw 'Local AI port is occupied.' }
$python = Join-Path $root 'artifacts/c2-python/.venv/Scripts/python.exe'
if (!(Test-Path -LiteralPath $python)) { throw 'Prepare the existing AI virtual environment from grpc_inference_service/requirements.txt first.' }
$key = $env:GEMINI_API_KEY
if (!$key) {
    [xml]$project = Get-Content (Join-Path $root 'Presentation/Presentation.csproj') -Raw
    $secretId = ($project.Project.PropertyGroup | Where-Object UserSecretsId | Select-Object -First 1).UserSecretsId
    if (!$secretId -or $secretId -match '[\\/]') { throw 'Unexpected UserSecretsId.' }
    $secretFile = Join-Path $env:APPDATA "Microsoft/UserSecrets/$secretId/secrets.json"
    if (Test-Path -LiteralPath $secretFile) {
        $secrets = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json -AsHashtable
        $key = $secrets['Llm:Gemini:ApiKey']
    }
}
if (!$key) { throw 'Configure GEMINI_API_KEY in the environment or Llm:Gemini:ApiKey in Presentation user-secrets; never put a key on the command line.' }
$groqRaw = @($env:GROQ_API_KEYS, $env:GROQ_API_KEY) -join ','
$groqModel = if ($env:GROQ_MODEL) { $env:GROQ_MODEL } else { 'openai/gpt-oss-120b' }
if (!$groqRaw.Trim(',')) {
    $envPath = Join-Path $root '.env'
    if (Test-Path -LiteralPath $envPath) {
        $groqLocal = @{}
        foreach ($line in Get-Content -LiteralPath $envPath) {
            if ($line -match '^\s*(GROQ_API_KEYS|GROQ_API_KEY)\s*=\s*(.*)$') {
                $groqLocal[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
            }
        }
        $groqRaw = @($groqLocal.GROQ_API_KEYS, $groqLocal.GROQ_API_KEY) -join ','
    }
}
$groqKeys = @($groqRaw -split '[,;\r\n]' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } |
    Where-Object { $_ } | Select-Object -Unique)
$runtimePath = Join-Path $root 'artifacts/local-learning/runtime.json'
if (!(Test-Path -LiteralPath $runtimePath)) { throw 'Initialize the isolated runtime with start-local-learning.ps1 -InitOnly first.' }
$runtime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json
if ($runtime.contentDatabase -notmatch '^TrafficContent_WebLearning_([a-f0-9]{8})$') {
    throw 'Unexpected isolated Content database name.'
}
$suffix = $Matches[1]
if ($runtime.userDatabase -ne "TrafficUser_WebLearning_$suffix") {
    throw 'User and Content databases must share one isolated runtime suffix.'
}
$response = Invoke-WebRequest 'http://127.0.0.1:16333/readyz' -TimeoutSec 5
if ($response.StatusCode -ne 200) { throw 'Local Qdrant is not ready.' }
$values = @{
    GEMINI_API_KEY = $key; GENERATION_PROVIDER = $(if ($GenerationProvider -eq 'auto' -and !$groqKeys.Count) { 'gemini' } else { $GenerationProvider }); GEMINI_MODEL = 'gemini-3.5-flash-lite'
    GEMINI_FALLBACK_MODEL = 'gemini-2.5-flash-lite'
    GEMINI_VISION_MODEL = 'gemini-3.5-flash-lite'; EMBEDDING_PROVIDER = 'gemini'; EMBEDDING_API_KEY = $key
    EMBEDDING_MODEL = 'gemini-embedding-001'; EMBEDDING_DIMENSION = '768'
    QDRANT_HOST = '127.0.0.1'; QDRANT_PORT = '16333'; QDRANT_COLLECTION = "traffic_law_learning_${suffix}_gemini768_v1"
    GRPC_PORT = '15051'; GRPC_BIND_HOST = '127.0.0.1'; PYTHONUNBUFFERED = '1'
}
if ($groqKeys.Count) {
    $values.GROQ_API_KEYS = $groqKeys -join ','
    $values.GROQ_API_KEY = ''
    if ($groqModel) { $values.GROQ_MODEL = $groqModel }
}
if (Get-NetTCPConnection -State Listen -LocalPort 14317 -ErrorAction SilentlyContinue) {
    $values.OTEL_EXPORTER_OTLP_ENDPOINT = 'http://127.0.0.1:14317'
}
$previous = @{}
foreach ($name in $values.Keys) { $previous[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
    foreach ($name in $values.Keys) { [Environment]::SetEnvironmentVariable($name, $values[$name]) }
    $process = Start-Process -FilePath $python -ArgumentList @($server) -WorkingDirectory $root -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $work 'inference.stdout.log') -RedirectStandardError (Join-Path $work 'inference.stderr.log')
    @{ id = $process.Id; marker = $server; port = 15051 } | ConvertTo-Json | Set-Content -LiteralPath $processPath -Encoding utf8
} finally {
    foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name]) }
    $key = $null; $groqRaw = $null; $groqKeys = @(); $values.Clear()
    if ($groqLocal) { $groqLocal.Clear() }
    if ($secrets) { $secrets.Clear() }
}
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) {
    if ($process.HasExited) { throw 'AI process exited. Inspect the ignored local-ai logs.' }
    if (Get-NetTCPConnection -State Listen -LocalPort 15051 -ErrorAction SilentlyContinue) {
        Write-Host 'Local AI ready on 127.0.0.1:15051; Qdrant on 127.0.0.1:16333. Credentials were not written to files.'
        return
    }
    Start-Sleep -Milliseconds 300
}
throw 'AI process did not become ready.'
