[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$UserConnection = $env:ConnectionStrings__UserConnection,
    [string]$ContentConnection = $env:ConnectionStrings__ContentConnection,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "../artifacts/c2-migrations")
)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
function Invoke-Ef([string[]]$Arguments) {
    & dotnet ef @Arguments --project (Join-Path $projectRoot "DataAccess") --startup-project (Join-Path $projectRoot "Presentation")
    if ($LASTEXITCODE -ne 0) { throw "EF command failed; no further database action was attempted." }
}
function Get-Target([string]$Connection) {
    $parts = New-Object System.Data.Common.DbConnectionStringBuilder
    # Explicit CLR access avoids PowerShell's IDictionary adapter treating ConnectionString as a key.
    $parts.set_ConnectionString($Connection)
    $server = if ($parts.ContainsKey("Server")) { $parts.get_Item("Server") } else { $parts.get_Item("Data Source") }
    $database = if ($parts.ContainsKey("Database")) { $parts.get_Item("Database") } else { $parts.get_Item("Initial Catalog") }
    if ([string]::IsNullOrWhiteSpace($server) -or [string]::IsNullOrWhiteSpace($database)) {
        throw "Each connection must explicitly identify Server/Data Source and Database/Initial Catalog."
    }
    if ($database -in @("master", "model", "msdb", "tempdb", "ChatAIWebDb")) {
        throw "System databases and the legacy ChatAIWebDb are not targets for new C2 migrations."
    }
    return "$server|$database".ToLowerInvariant()
}
if ($Apply) {
    if (!$UserConnection -or !$ContentConnection) {
        throw "Apply requires explicit UserConnection and ContentConnection arguments or environment variables."
    }
    if ((Get-Target $UserConnection) -eq (Get-Target $ContentConnection)) {
        throw "User and Content must use different SQL databases."
    }
}
$oldUserConnection = $env:ConnectionStrings__UserConnection
$oldContentConnection = $env:ConnectionStrings__ContentConnection
try {
    if ($UserConnection) { $env:ConnectionStrings__UserConnection = $UserConnection }
    if ($ContentConnection) { $env:ConnectionStrings__ContentConnection = $ContentConnection }
    [IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory)) | Out-Null
    foreach ($dbContext in @("UserDbContext", "ContentDbContext")) {
        Invoke-Ef -Arguments @("migrations", "has-pending-model-changes", "--context", $dbContext)
        Invoke-Ef -Arguments @("migrations", "script", "--idempotent", "--context", $dbContext, "--output", (Join-Path $OutputDirectory "$dbContext.sql"))
    }
    if ($Apply) {
        # Independent databases: if the second fails, rerun after fixing it; do not claim a global transaction.
        Invoke-Ef -Arguments @("database", "update", "--context", "UserDbContext")
        Invoke-Ef -Arguments @("database", "update", "--context", "ContentDbContext")
        Write-Host "Both C2 database migration commands completed."
    } else {
        Write-Host "SQL scripts generated; no database migrations applied. Review scripts before using -Apply."
    }
}
finally {
    $env:ConnectionStrings__UserConnection = $oldUserConnection
    $env:ConnectionStrings__ContentConnection = $oldContentConnection
}
