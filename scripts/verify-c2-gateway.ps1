[CmdletBinding()]
param(
    [string]$UserConnection = $env:ConnectionStrings__UserConnection,
    [string]$ContentConnection = $env:ConnectionStrings__ContentConnection,
    [int]$UserPort = 15039,
    [int]$ContentPort = 15040,
    [int]$GatewayPort = 15080
)
$ErrorActionPreference = "Stop"
if (!$UserConnection -or !$ContentConnection) { throw "Provide two already-migrated test database connections." }
$projectRoot = Split-Path -Parent $PSScriptRoot
$runDirectory = Join-Path $projectRoot ("artifacts/c2-smoke/" + [Guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($runDirectory) | Out-Null
$startedProcesses = [Collections.Generic.List[Diagnostics.Process]]::new()
$checks = [Collections.Generic.List[object]]::new()
$envNames = @("Jwt__SecretKey", "ConnectionStrings__UserConnection", "ConnectionStrings__ContentConnection",
    "Database__MigrateOnStartup", "ContentService__Address", "Logging__FilePath", "Chat__AttachmentRoot",
    "ReverseProxy__Clusters__user__Destinations__user__Address",
    "ReverseProxy__Clusters__content__Destinations__content__Address")
$oldEnvironment = @{}
foreach ($envName in $envNames) { $oldEnvironment[$envName] = [Environment]::GetEnvironmentVariable($envName) }
function Start-Host([string]$Name, [string]$Assembly, [string]$Directory, [string[]]$Arguments) {
    $env:Logging__FilePath = Join-Path $runDirectory "$Name.jsonl"
    $process = Start-Process -FilePath "dotnet" -ArgumentList (@($Assembly) + $Arguments) -WorkingDirectory $Directory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runDirectory "$Name.stdout.log") -RedirectStandardError (Join-Path $runDirectory "$Name.stderr.log")
    $startedProcesses.Add($process)
}
function Wait-Host([string]$Address) {
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        try {
            if ((Invoke-WebRequest "$Address/health/live" -SkipHttpErrorCheck -TimeoutSec 2).StatusCode -eq 200) { return }
        } catch { }
        Start-Sleep -Milliseconds 250
    }
    throw "Host did not become live; inspect local artifacts/c2-smoke logs."
}
function Check([string]$Name, [string]$Url, [int]$Expected, [string]$Method = "GET", [object]$Body = $null, [hashtable]$Headers = @{}) {
    $request = @{Uri=$Url;Method=$Method;Headers=$Headers;SkipHttpErrorCheck=$true;TimeoutSec=15}
    if ($null -ne $Body) { $request.Body = $Body | ConvertTo-Json -Depth 15; $request.ContentType = "application/json" }
    $response = Invoke-WebRequest @request
    $checks.Add([pscustomobject]@{Check=$Name;Expected=$Expected;Actual=[int]$response.StatusCode})
    if ($response.StatusCode -ne $Expected) { throw "Check failed: $Name (HTTP $($response.StatusCode))." }
    return $response
}
try {
    foreach ($port in @($UserPort, $ContentPort, $GatewayPort)) {
        if ([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains $port) { throw "Test port $port is occupied." }
    }
    $env:Jwt__SecretKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
    $env:ConnectionStrings__UserConnection = $UserConnection
    $env:ConnectionStrings__ContentConnection = $ContentConnection
    $env:Database__MigrateOnStartup = "false"
    $env:Chat__AttachmentRoot = Join-Path $runDirectory "attachments"
    $userAddress = "http://127.0.0.1:$UserPort"
    $contentAddress = "http://127.0.0.1:$ContentPort"
    $gatewayAddress = "http://127.0.0.1:$GatewayPort"
    $env:ContentService__Address = "$contentAddress/"
    Start-Host -Name user -Assembly "./bin/Debug/net8.0/Presentation.dll" -Directory (Join-Path $projectRoot "Presentation") -Arguments @("--urls", $userAddress, "--Service:Module", "User")
    Start-Host -Name content -Assembly "./bin/Debug/net8.0/Presentation.dll" -Directory (Join-Path $projectRoot "Presentation") -Arguments @("--urls", $contentAddress, "--Service:Module", "Content")
    $env:ReverseProxy__Clusters__user__Destinations__user__Address = "$userAddress/"
    $env:ReverseProxy__Clusters__content__Destinations__content__Address = "$contentAddress/"
    Start-Host -Name gateway -Assembly "./bin/Debug/net8.0/ApiGateway.dll" -Directory (Join-Path $projectRoot "ApiGateway") -Arguments @("--urls", $gatewayAddress)
    foreach ($address in @($userAddress, $contentAddress, $gatewayAddress)) { Wait-Host $address }
    $null = Check "User SQL readiness through Gateway" "$gatewayAddress/health/ready" 200
    $null = Check "Content SQL readiness through Gateway" "$gatewayAddress/health/content/ready" 200
    $null = Check "Content documents route" "$gatewayAddress/api/documents" 200
    $null = Check "User host hides content controller" "$userAddress/api/documents" 404
    $null = Check "Content host hides auth controller" "$contentAddress/api/auth/profile" 404
    $null = Check "Gateway blocks internal endpoint" "$gatewayAddress/internal/content/chunks" 404 "POST" @()
    $null = Check "Content internal endpoint requires service auth" "$contentAddress/internal/content/chunks" 401 "POST" @()
    $suffix = [Guid]::NewGuid().ToString("N").Substring(0, 12)
    $password = [Guid]::NewGuid().ToString("N") + "!aA1"
    $register = Check "Register through Gateway and User SQL" "$gatewayAddress/api/auth/register" 201 "POST" @{username="c2_$suffix";email="c2_$suffix@test.local";password=$password}
    $auth = $register.Content | ConvertFrom-Json
    $headers = @{Authorization="Bearer $($auth.accessToken)"}
    $null = Check "Profile through Gateway" "$gatewayAddress/api/auth/profile" 200 "GET" $null $headers
    $session = Check "Create chat session in User SQL" "$gatewayAddress/api/chats" 201 "POST" @{title="C2 smoke"} $headers
    $sessionId = ($session.Content | ConvertFrom-Json).id
    $null = Check "Read saved chat session" "$gatewayAddress/api/chats/$sessionId" 200 "GET" $null $headers
    $refresh = Check "Stateless refresh through Gateway" "$gatewayAddress/api/auth/refresh-token" 200 "POST" @{refreshToken=$auth.refreshToken}
    if (($refresh.Content | ConvertFrom-Json).refreshToken -ne $auth.refreshToken) { throw "Refresh must preserve its original absolute expiry/token." }
    $null = Check "Refresh token cannot authenticate as access token" "$gatewayAddress/api/auth/profile" 401 "GET" $null @{Authorization="Bearer $($auth.refreshToken)"}
    $null = Check "Logout response" "$gatewayAddress/api/auth/logout" 204 "POST" @{refreshToken=$auth.refreshToken}
    $checks | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDirectory "checks.json") -Encoding utf8
    $checks | Format-Table -AutoSize
    Write-Host "Smoke evidence saved under $runDirectory (tokens are not included in checks.json)."
}
finally {
    foreach ($process in $startedProcesses) {
        if (!$process.HasExited) { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue }
    }
    foreach ($envName in $envNames) { [Environment]::SetEnvironmentVariable($envName, $oldEnvironment[$envName]) }
}
