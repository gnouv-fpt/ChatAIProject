[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root 'artifacts/question-bank-600'
[void][IO.Directory]::CreateDirectory($work)
function Get-PinnedSource($url, $filename, $sha) {
    $target = Join-Path $work $filename
    if (Test-Path -LiteralPath $target) {
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $sha) {
            throw "Existing source has unexpected bytes: $filename. It was not overwritten."
        }
        return
    }
    $download = Join-Path $work ([Guid]::NewGuid().ToString('N') + '.download')
    Invoke-WebRequest -Uri $url -OutFile $download -TimeoutSec 60
    if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $sha) {
        throw "Source download does not match pinned SHA-256: $filename. No package or database was changed."
    }
    Move-Item -LiteralPath $download -Destination $target
}
Get-PinnedSource 'https://khodulieu.sohoa.tuyenquang.gov.vn/congthongtin/media/edb12a6ad8ecfde537ec02cbb7e2a1b1.pdf' `
    'source-download.pdf' 'd473be679b53458a33acc52057f3a4fe532ea489e91d88fb86789073cd98a9c5'
Get-PinnedSource 'https://cdn.thuvienphapluat.vn/uploads/DanLuat-BanAn/2025/5/huong-dan-so-2262-csgt-p5.pdf' `
    'guide-mirror.pdf' 'dcb0b42473a23af3b006ed07cfd3a728254eb3d5263f6a26d0536c576d69e634'
Push-Location $root
try {
    python -X utf8 scripts/build-question-bank-600.py --pdf (Join-Path $work 'source-download.pdf') `
        --guide (Join-Path $work 'guide-mirror.pdf') --output-dir content-bank/csgt-2025
    if ($LASTEXITCODE) { throw 'Question source extraction failed.' }
} finally { Pop-Location }
