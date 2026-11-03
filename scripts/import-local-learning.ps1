[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root 'artifacts/local-learning'
$runtime = Get-Content (Join-Path $work 'runtime.json') -Raw | ConvertFrom-Json
$package = Get-Content (Join-Path $work 'package.json') -Raw | ConvertFrom-Json
if (!$package.evidence.localOnly -or $runtime.content -ne 'http://127.0.0.1:15040' -or $runtime.user -ne 'http://127.0.0.1:15039') {
    throw 'Importer only targets the isolated local-learning hosts.'
}
$loginBody = @{ email = $runtime.adminEmail; password = $runtime.adminPassword } | ConvertTo-Json
$login = Invoke-RestMethod "$($runtime.user)/api/auth/login" -Method Post -ContentType 'application/json' -Body $loginBody
$headers = @{ Authorization = "Bearer $($login.accessToken)" }
function Content-Request($path, $body) {
    Invoke-RestMethod ($runtime.content + $path) -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' `
        -Body ([Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 30 -Compress)))
}
$preview = Content-Request '/api/admin/question-banks/import' @{ bank = $package.bank }
if ($preview.errors.Count) { throw ($preview.errors -join ' ') }
$id = $package.bank.id; $version = $package.bank.version
# Source/answer identity is checked by the builder against the approved local PDF extraction.
$published = Content-Request "/api/admin/question-banks/$id/versions/$version/publish" @{
    expectedHash = $preview.summary.hash; sourceAndAnswersReviewed = $true
}
$existing = Invoke-RestMethod "$($runtime.content)/api/exam-templates/drafts" -Headers $headers
foreach ($template in $package.templates) {
    $found = $existing | Where-Object { $_.examCode -eq $template.examCode -and $_.version -eq $template.version }
    if ($found) {
        if (($found.questionIds -join ',') -ne ($template.questionIds -join ',') -or $found.durationMinutes -ne $template.durationMinutes -or $found.passingScore -ne $template.passingScore) {
            throw "Existing template differs: $($template.examCode)"
        }
    } else { $null = Content-Request '/api/exam-templates/import' $template }
    $null = Content-Request "/api/exam-templates/$($template.examCode)/versions/$($template.version)/publish" @{}
}
$evidence = @{ bankId = $id; bankVersion = $version; questionCount = $published.questionCount; templates = $package.templates.Count;
    packageHash = $preview.summary.hash; localOnly = $true; gateway = $runtime.gateway }
$evidence | ConvertTo-Json | Set-Content (Join-Path $work 'import-result.json') -Encoding utf8
$evidence | Format-List
