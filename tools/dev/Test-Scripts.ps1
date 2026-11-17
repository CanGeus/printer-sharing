#Requires -Version 5.1
<#
.SYNOPSIS
    Memeriksa kualitas script toolkit: sintaks, kompatibilitas PS 2.0, dan lint.

.DESCRIPTION
    Tiga lapis pemeriksaan:

      1. Sintaks
         Setiap file .ps1 harus bisa di-parse tanpa error.

      2. Kompatibilitas PowerShell 2.0
         File yang diawali "#Requires -Version 2.0" harus bebas dari konstruksi
         PowerShell 3.0+ agar tetap berjalan di Windows 7, dan isinya harus
         ASCII murni atau UTF-8 ber-BOM.

      3. Lint
         Menjalankan PSScriptAnalyzer memakai PSScriptAnalyzerSettings.psd1
         (bila modulnya terpasang).

    Keluar dengan kode 1 bila ada temuan, sehingga bisa dipakai di CI.

.PARAMETER FailOnWarning
    Perlakukan temuan lint berlevel Warning sebagai kegagalan.

.PARAMETER SkipLint
    Lewati tahap PSScriptAnalyzer (mis. bila modul tidak tersedia).

.EXAMPLE
    .\tools\dev\Test-Scripts.ps1

.EXAMPLE
    .\tools\dev\Test-Scripts.ps1 -FailOnWarning
#>
[CmdletBinding()]
param(
    [switch]$FailOnWarning,
    [switch]$SkipLint
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Write-Section {
    param([string]$Text)
    Write-Host ''
    Write-Host ('== ' + $Text + ' ' + ('=' * [Math]::Max(1, 56 - $Text.Length))) -ForegroundColor Cyan
}

# Ganti seluruh komentar dengan spasi, supaya kata kunci yang disebut di dalam
# komentar (mis. "$PSScriptRoot") tidak dianggap sebagai pemakaian sungguhan.
function Get-CodeOnlyText {
    param(
        [string]$Text,
        [System.Management.Automation.Language.Token[]]$Tokens
    )
    $chars = $Text.ToCharArray()
    foreach ($t in $Tokens) {
        if ($t.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment) {
            for ($i = $t.Extent.StartOffset; $i -lt $t.Extent.EndOffset; $i++) {
                $chars[$i] = ' '
            }
        }
    }
    return (-join $chars)
}

# Konstruksi yang TIDAK ada di PowerShell 2.0 (Windows 7).
$ps2Patterns = @(
    @{ Pattern = '\$PSScriptRoot';                     Message = 'Pakai Split-Path -Parent $MyInvocation.MyCommand.Definition (PS 2.0).' }
    @{ Pattern = '\$using:';                           Message = '$using: baru ada di PS 3.0.' }
    @{ Pattern = '\[ordered\]';                        Message = 'Ordered hashtable [ordered] baru ada di PS 3.0.' }
    @{ Pattern = '\[pscustomobject\]';                 Message = '[pscustomobject] baru ada di PS 3.0; pakai New-Object PSObject.' }
    @{ Pattern = '\bGet-CimInstance\b';                Message = 'Get-CimInstance baru ada di PS 3.0; pakai Get-WmiObject.' }
    @{ Pattern = '\b(Get|New|Remove)-CimSession\b';    Message = 'CimCmdlets baru ada di PS 3.0.' }
    @{ Pattern = 'Get-Content[^\r\n]*-Raw';            Message = 'Switch -Raw pada Get-Content baru ada di PS 3.0.' }
    @{ Pattern = '\bConvertFrom-Json\b';               Message = 'ConvertFrom-Json baru ada di PS 3.0.' }
    @{ Pattern = '\bConvertTo-Json\b';                 Message = 'ConvertTo-Json baru ada di PS 3.0.' }
    @{ Pattern = '\bInvoke-RestMethod\b';              Message = 'Invoke-RestMethod baru ada di PS 3.0.' }
    @{ Pattern = '\bGet-FileHash\b';                   Message = 'Get-FileHash baru ada di PS 4.0.' }
    @{ Pattern = '\bGet-ItemPropertyValue\b';          Message = 'Get-ItemPropertyValue baru ada di PS 5.0.' }
    @{ Pattern = '\b(Expand|Compress)-Archive\b';      Message = 'Expand/Compress-Archive baru ada di PS 5.0.' }
    @{ Pattern = '\bNew-TemporaryFile\b';              Message = 'New-TemporaryFile baru ada di PS 5.0.' }
    @{ Pattern = '::new\s*\(';                         Message = 'Static ::new() baru ada di PS 5.0; pakai New-Object.' }
    @{ Pattern = '(?m)^\s*class\s+[A-Za-z_]';          Message = 'class baru ada di PS 5.0.' }
    @{ Pattern = '(?m)^\s*enum\s+[A-Za-z_]';           Message = 'enum baru ada di PS 5.0.' }
    @{ Pattern = '\?\?';                               Message = 'Operator ?? (null-coalescing) baru ada di PS 7.' }
    @{ Pattern = '\?\.';                               Message = 'Operator ?. (null-conditional) baru ada di PS 7.' }
    @{ Pattern = 'ForEach-Object[^\r\n]*-Parallel';    Message = 'Switch -Parallel baru ada di PS 7.' }
    @{ Pattern = 'Get-ChildItem[^\r\n]*\s-(File|Directory)\b'; Message = 'Switch -File/-Directory baru ada di PS 3.0.' }
)

# ---------------------------------------------------------------------------
# Kumpulkan file
# ---------------------------------------------------------------------------
$files = @(Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.ps1' -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    Sort-Object FullName)

$syntaxErrors = New-Object System.Collections.ArrayList
$compatIssues = New-Object System.Collections.ArrayList
$lintErrors   = New-Object System.Collections.ArrayList
$lintWarnings = New-Object System.Collections.ArrayList
$ps2Count     = 0

Write-Section 'Sintaks & kompatibilitas PowerShell 2.0'

foreach ($f in $files) {
    $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')

    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)

    if ($errors.Count -gt 0) {
        foreach ($e in $errors) {
            [void]$syntaxErrors.Add(('{0}:{1}  {2}' -f $rel, $e.Extent.StartLineNumber, $e.Message))
        }
        Write-Host ('  [FAIL] {0}  ({1} error sintaks)' -f $rel, $errors.Count) -ForegroundColor Red
        continue
    }

    $raw = Get-Content -LiteralPath $f.FullName -Raw
    $isPs2 = ($raw -match '(?m)^#Requires\s+-Version\s+2\.0')

    if ($isPs2) {
        $ps2Count++
        $code = Get-CodeOnlyText -Text $raw -Tokens $tokens
        foreach ($p in $ps2Patterns) {
            if ($code -match $p.Pattern) {
                [void]$compatIssues.Add(('{0}  ->  {1}' -f $rel, $p.Message))
            }
        }

        # PowerShell 2.0 salah membaca karakter non-ASCII tanpa BOM.
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $nonAscii = $false
        foreach ($b in $bytes) { if ($b -gt 127) { $nonAscii = $true; break } }
        if ($nonAscii -and -not $hasBom) {
            [void]$compatIssues.Add(('{0}  ->  berisi karakter non-ASCII tanpa BOM UTF-8 (PS 2.0 bisa salah baca).' -f $rel))
        }

        Write-Host ('  [ OK ] {0}  (target PS 2.0)' -f $rel) -ForegroundColor Green
    }
    else {
        Write-Host ('  [ OK ] {0}' -f $rel) -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Lint
# ---------------------------------------------------------------------------
if (-not $SkipLint) {
    Write-Section 'Lint (PSScriptAnalyzer)'
    if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        $settingsPath = Join-Path $Root 'PSScriptAnalyzerSettings.psd1'

        foreach ($f in $files) {
            $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/')
            $results = @(Invoke-ScriptAnalyzer -Path $f.FullName -Settings $settingsPath -ErrorAction Stop)

            foreach ($r in $results) {
                $line = ('{0}:{1}  {2}  [{3}]' -f $rel, $r.Line, $r.Message, $r.RuleName)
                if ([string]$r.Severity -eq 'Error') { [void]$lintErrors.Add($line) }
                else { [void]$lintWarnings.Add($line) }
            }

            if ($results.Count -eq 0) {
                Write-Host ('  [ OK ] {0}' -f $rel) -ForegroundColor Green
            }
            else {
                Write-Host ('  [LINT] {0}  ({1} temuan)' -f $rel, $results.Count) -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host '  [SKIP] PSScriptAnalyzer tidak terpasang.' -ForegroundColor DarkGray
        Write-Host '         Install-Module PSScriptAnalyzer -Scope CurrentUser -Force' -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# Detail temuan
# ---------------------------------------------------------------------------
if ($syntaxErrors.Count -gt 0) {
    Write-Section 'Error sintaks'
    foreach ($m in $syntaxErrors) { Write-Host ('  - ' + $m) -ForegroundColor Red }
}
if ($compatIssues.Count -gt 0) {
    Write-Section 'Pelanggaran kompatibilitas PowerShell 2.0'
    foreach ($m in $compatIssues) { Write-Host ('  - ' + $m) -ForegroundColor Red }
}
if ($lintErrors.Count -gt 0) {
    Write-Section 'Lint - Error'
    foreach ($m in $lintErrors) { Write-Host ('  - ' + $m) -ForegroundColor Red }
}
if ($lintWarnings.Count -gt 0) {
    Write-Section 'Lint - Warning'
    foreach ($m in $lintWarnings) { Write-Host ('  - ' + $m) -ForegroundColor Yellow }
}

# ---------------------------------------------------------------------------
# Ringkasan
# ---------------------------------------------------------------------------
Write-Section 'Ringkasan'
Write-Host ('  File .ps1 diperiksa   : {0}' -f $files.Count)
Write-Host ('  File target PS 2.0    : {0}' -f $ps2Count)
Write-Host ('  Error sintaks         : {0}' -f $syntaxErrors.Count)
Write-Host ('  Pelanggaran PS 2.0    : {0}' -f $compatIssues.Count)
Write-Host ('  Lint error / warning  : {0} / {1}' -f $lintErrors.Count, $lintWarnings.Count)

$failed = ($syntaxErrors.Count -gt 0) -or
          ($compatIssues.Count -gt 0) -or
          ($lintErrors.Count -gt 0) -or
          ($FailOnWarning -and $lintWarnings.Count -gt 0)

Write-Host ''
if ($failed) {
    Write-Host '  HASIL: GAGAL' -ForegroundColor Red
    exit 1
}

Write-Host '  HASIL: LULUS' -ForegroundColor Green
exit 0
