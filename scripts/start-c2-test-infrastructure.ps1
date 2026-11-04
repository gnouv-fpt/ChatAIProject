[CmdletBinding()]
param([switch]$Stop, [switch]$Ai, [switch]$Sql)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
$previous = @{}
$previousDockerConfig = $env:DOCKER_CONFIG
$previousDockerHost = $env:DOCKER_HOST
try {
    # Public images need no registry login. A local config avoids a broken
    # Docker Desktop credential helper without changing the user's Docker config.
    $dockerConfig = Join-Path $root 'artifacts/local-learning/docker-public-config'
    [void][IO.Directory]::CreateDirectory($dockerConfig)
    [IO.File]::WriteAllText((Join-Path $dockerConfig 'config.json'), '{"auths":{}}', [Text.UTF8Encoding]::new($false))
    $env:DOCKER_CONFIG = $dockerConfig
    if (!$env:DOCKER_HOST) { $env:DOCKER_HOST = 'npipe:////./pipe/dockerDesktopLinuxEngine' }
    # These only satisfy interpolation in services that this command does not start.
    foreach ($name in @('SA_PASSWORD','JWT_SECRET_KEY','GRAFANA_PASSWORD')) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name)
        if (!$previous[$name]) {
            [Environment]::SetEnvironmentVariable($name,
                [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48)) + 'aA1!')
        }
    }
    $composeArgs = @('-p','prn-c2-localtest','-f','docker-compose.yml','-f','docker-compose.c2-test.yml')
    $services = @('redis', 'kafka', 'kafka-init')
    if ($Ai) { $services += 'qdrant' }
    if ($Sql) { $services += 'sqlserver' }
    if ($Stop) { docker-compose @composeArgs stop @services }
    else { docker-compose @composeArgs up -d @services }
    if ($LASTEXITCODE) { throw 'Could not start/stop the isolated C2 test infrastructure.' }
}
finally {
    foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name]) }
    $env:DOCKER_CONFIG = $previousDockerConfig
    $env:DOCKER_HOST = $previousDockerHost
    Pop-Location
}
