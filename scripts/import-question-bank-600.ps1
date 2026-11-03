[CmdletBinding()]
param([switch]$Https, [switch]$OfficialB)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ($Https -and $OfficialB) { throw 'Choose one edition.' }
$work = Join-Path $root $(if ($OfficialB) { 'artifacts/official-profile' } elseif ($Https) { 'artifacts/question-bank-https' } else { 'artifacts/question-bank-600' })
[void][IO.Directory]::CreateDirectory($work)
$runtime = Get-Content (Join-Path $root 'artifacts/local-learning/runtime.json') -Raw | ConvertFrom-Json
$packagePath = Join-Path $root $(if ($OfficialB) { 'content-bank/csgt-2025-B-current/package.json' } elseif ($Https) { 'content-bank/csgt-2025-https/package.json' } else { 'content-bank/csgt-2025/package.json' })
$package = Get-Content $packagePath -Raw | ConvertFrom-Json
if ($runtime.content -ne 'http://127.0.0.1:15040' -or $runtime.user -ne 'http://127.0.0.1:15039' -or
    $runtime.contentDatabase -notmatch '^TrafficContent_WebLearning_[a-f0-9]{8}$' -or !$package.evidence.localOnly -or
    (!$package.evidence.practiceOnly -and !$OfficialB) -or $package.bank.questions.Count -ne 600) {
    throw 'Importer restricted to the isolated local-learning database and the verified practice package.'
}
# Confirm this port still belongs to the Content process started by our local launcher.
$saved = Get-Content (Join-Path $root 'artifacts/local-learning/processes.json') -Raw | ConvertFrom-Json
$record = $saved | Where-Object name -eq 'content'
$process = Get-CimInstance Win32_Process -Filter "ProcessId = $($record.id)"
$listener = Get-NetTCPConnection -State Listen -LocalPort 15040
if (!$process -or !$process.CommandLine.Contains($record.marker) -or $listener.OwningProcess -ne $record.id) {
    throw 'Content host does not match the recorded local-learning process.'
}
Push-Location $root
try {
    # Recheck all source metadata, original assets, accepted scenes and the exact package before writes.
    if ($OfficialB) { python -X utf8 scripts/prepare-official-b-bank.py --verify }
    elseif ($Https) { python -X utf8 scripts/prepare-question-bank-https.py --verify }
    else { python -X utf8 scripts/verify-question-bank-600.py }
    if ($LASTEXITCODE) { throw 'Source/package verification failed; no import attempted.' }
    $loginBody = @{ email = $runtime.adminEmail; password = $runtime.adminPassword } | ConvertTo-Json
    $login = Invoke-RestMethod "$($runtime.user)/api/auth/login" -Method Post -ContentType 'application/json' -Body $loginBody
    $headers = @{ Authorization = "Bearer $($login.accessToken)" }
    function Read-Content($path) {
        $response = Invoke-RestMethod ($runtime.content + $path) -Headers $headers
        foreach ($item in $response) { $item }
    }
    function Write-Content($path, $body) {
        Invoke-RestMethod ($runtime.content + $path) -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' `
            -Body ([Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 40 -Compress)))
    }
    $before = @(Read-Content '/api/admin/question-banks')
    $templatesBefore = @(Read-Content '/api/exam-templates/drafts')
    $oldId = $package.evidence.preservedBankId
    $old = $before | Where-Object { $_.id -eq $oldId -and $_.version -eq '1' }
    if (!$old -or $old.questionCount -ne 115 -or !$old.isPublished) { throw 'Expected preserved 115-question bank is missing.' }
    $oldCode = ([Guid]$oldId).ToString('N')
    $sqlCount = & sqlcmd -S '.\MSSQLSERVER_VUON' -E -d $runtime.contentDatabase -h -1 -W -b `
        -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM TrafficQuestions WHERE BankCode = '$oldCode' AND BankVersion = 1;"
    if ($LASTEXITCODE -or ($sqlCount | Out-String).Trim() -ne '115') { throw 'Isolated SQL database does not contain the expected source bank.' }
    # Preflight every existing template before importing anything. A rerun never edits existing rows.
    foreach ($template in $package.templates) {
        $found = $templatesBefore | Where-Object { $_.examCode -eq $template.examCode -and $_.version -eq $template.version }
        if ($found -and (($found.questionIds -join ',') -ne ($template.questionIds -join ',') -or
                $found.title -ne $template.title -or $found.durationMinutes -ne $template.durationMinutes -or
                $found.passingScore -ne $template.passingScore)) { throw "Existing template differs: $($template.examCode)" }
    }
    $beforePath = Join-Path $work 'before-import.json'
    if (!(Test-Path $beforePath)) {
        @{ banks = $before; templates = $templatesBefore; database = $runtime.contentDatabase } |
            ConvertTo-Json -Depth 40 | Set-Content $beforePath -Encoding utf8
    }
    $preview = Write-Content '/api/admin/question-banks/import' @{ bank = $package.bank }
    if ($preview.errors.Count) { throw ($preview.errors -join ' ') }
    $id = $package.bank.id; $version = $package.bank.version
    $published = Write-Content "/api/admin/question-banks/$id/versions/$version/publish" @{
        expectedHash = $preview.summary.hash; sourceAndAnswersReviewed = $true
    }
    foreach ($template in $package.templates) {
        $found = $templatesBefore | Where-Object { $_.examCode -eq $template.examCode -and $_.version -eq $template.version }
        if (!$found) { $null = Write-Content '/api/exam-templates/import' $template }
        $null = Write-Content "/api/exam-templates/$($template.examCode)/versions/$($template.version)/publish" @{}
    }
    $after = @(Read-Content '/api/admin/question-banks')
    foreach ($prior in $before) {
        if ($prior.id -eq $id -and $prior.version -eq $version) { continue } # draft -> published is intentional on recovery
        $current = $after | Where-Object { $_.id -eq $prior.id -and $_.version -eq $prior.version }
        if (!$current -or $current.hash -ne $prior.hash -or $current.questionCount -ne $prior.questionCount -or
            $current.isPublished -ne $prior.isPublished) { throw 'An existing bank changed unexpectedly.' }
    }
    $afterTemplates = @(Read-Content '/api/exam-templates/drafts')
    foreach ($prior in $templatesBefore) {
        if ($prior.examCode -in @($package.templates.examCode)) { continue } # preflight already checked immutable template fields
        $current = $afterTemplates | Where-Object { $_.id -eq $prior.id }
        if (!$current -or ($current | ConvertTo-Json -Depth 10 -Compress) -ne ($prior | ConvertTo-Json -Depth 10 -Compress)) {
            throw 'An existing template changed unexpectedly.'
        }
    }
    $evidence = @{ bankId = $id; version = $version; questionCount = $published.questionCount;
        packageHash = $preview.summary.hash; practiceTemplates = $package.templates.Count;
        contentDatabase = $runtime.contentDatabase; preservedBankId = $oldId; preservedBankHash = $old.hash;
        banksInDatabase = $after.Count; templatesInDatabase = $afterTemplates.Count; localOnly = $true }
    $evidence | ConvertTo-Json | Set-Content (Join-Path $work 'import-result.json') -Encoding utf8
    $evidence | Format-List
} finally { Pop-Location }
