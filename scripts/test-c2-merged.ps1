[CmdletBinding()]
param(
    [string]$SqlServerConnection = $env:C2_TEST_SQL,
    [string]$Redis = 'localhost:16379',
    [string]$Kafka = 'localhost:19092'
)
$ErrorActionPreference = 'Stop'
if (!$SqlServerConnection) { throw 'Provide -SqlServerConnection without a Database/Initial Catalog; use a local test SQL Server.' }
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
$names = @('BAO_TEST_SQL','C2_TEST_SQL','C2_TEST_REDIS','C2_TEST_KAFKA','VUONG_TEST_SQL','ConnectionStrings__UserConnection')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
    $target = [System.Data.Common.DbConnectionStringBuilder]::new()
    $target.set_ConnectionString($SqlServerConnection)
    if ($target.ContainsKey('Database') -or $target.ContainsKey('Initial Catalog')) {
        throw 'Use a server-only connection. The verifier generates its own isolated database name.'
    }
    $env:BAO_TEST_SQL = $SqlServerConnection
    $env:C2_TEST_SQL = $SqlServerConnection
    $env:C2_TEST_REDIS = $Redis
    $env:C2_TEST_KAFKA = $Kafka
    $env:ConnectionStrings__UserConnection = $SqlServerConnection.TrimEnd(';') + ';Database=TrafficUser_C2Tests_' + [Guid]::NewGuid().ToString('N')
    $env:VUONG_TEST_SQL = $env:ConnectionStrings__UserConnection
    dotnet build ChatAIWeb.slnx --nologo -v quiet
    if ($LASTEXITCODE) { throw 'Merged solution build failed.' }
    dotnet ef database update --context UserDbContext --project DataAccess --startup-project Presentation --no-build
    if ($LASTEXITCODE) { throw 'Isolated User test database migration failed.' }
    dotnet test ChatAIWeb.slnx --no-build --nologo -v quiet --logger 'trx;LogFilePrefix=c2-final' --results-directory artifacts/test-results
    if ($LASTEXITCODE) { throw 'Merged tests failed; inspect artifacts/test-results.' }
    Write-Host 'The generated TrafficUser_C2Tests database is retained for review; existing databases were not migrated.'
}
finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$previous[$name]) }
    Pop-Location
}
