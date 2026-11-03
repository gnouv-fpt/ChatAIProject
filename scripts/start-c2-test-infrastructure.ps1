[CmdletBinding()]
param([switch]$Stop, [switch]$Ai)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
$previous = @{}
try {
    # These only satisfy interpolation in services that this command does not start.
    foreach ($name in @('SA_PASSWORD','JWT_SECRET_KEY','GRAFANA_PASSWORD')) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name)
        if (!$previous[$name]) {
            [Environment]::SetEnvironmentVariable($name,
                [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48)) + 'aA1!')
        }
    }
    $composeArgs = @('compose','-p','prn-c2-localtest','-f','docker-compose.yml','-f','docker-compose.c2-test.yml')
    $services = @('redis', 'kafka', 'kafka-init')
    if ($Ai) { $services += 'qdrant' }
    if ($Stop) { docker @composeArgs stop @services }
    else { docker @composeArgs up -d @services }
    if ($LASTEXITCODE) { throw 'Could not start/stop the isolated C2 test infrastructure.' }
}
finally {
    foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name]) }
    Pop-Location
}
