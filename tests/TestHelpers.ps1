#Requires -Version 5.1
<#
.SYNOPSIS
    Fungsi bantu untuk file Pester di folder tests\.

.DESCRIPTION
    Berisi tiga hal:

      1. Assertion portabel.
         Sintaks Should berbeda antar versi Pester:

           - Pester 3.x (bawaan Windows PowerShell 5.1) memakai "Should Be".
           - Pester 4/5/6 memakai "Should -Be".

         Supaya file test yang sama tetap jalan di semua versi, test memakai
         helper di bawah ini. Helper melempar exception saat gagal, dan Pester
         melaporkannya sebagai test yang gagal.

      2. Deteksi versi Pester, dipakai untuk memilih cara setup yang tepat
         (lihat catatan di file *.Tests.ps1).

      3. Daftar file wajib dan pemanggil pemeriksa kualitas.
#>

function Assert-True {
    param(
        [AllowNull()]$Condition,
        [string]$Message = 'Kondisi seharusnya true.'
    )
    if (-not $Condition) { throw $Message }
}

function Assert-False {
    param(
        [AllowNull()]$Condition,
        [string]$Message = 'Kondisi seharusnya false.'
    )
    if ($Condition) { throw $Message }
}

function Assert-Equal {
    param(
        [AllowNull()]$Actual,
        [AllowNull()]$Expected,
        [string]$Message = ''
    )
    if (-not [object]::Equals($Actual, $Expected)) {
        $prefix = ''
        if ($Message -ne '') { $prefix = $Message + ' ' }
        throw ('{0}Harap <{1}>, dapat <{2}>.' -f $prefix, $Expected, $Actual)
    }
}

function Assert-NotNull {
    param(
        [AllowNull()]$Value,
        [string]$Message = 'Nilai seharusnya tidak null.'
    )
    if ($null -eq $Value) { throw $Message }
}

function Assert-Match {
    param(
        [AllowNull()][string]$Actual,
        [string]$Pattern,
        [string]$Message = ''
    )
    if ($Actual -notmatch $Pattern) {
        $prefix = ''
        if ($Message -ne '') { $prefix = $Message + ' ' }
        throw ('{0}<{1}> seharusnya cocok dengan <{2}>.' -f $prefix, $Actual, $Pattern)
    }
}

function Assert-NotMatch {
    param(
        [AllowNull()][string]$Actual,
        [string]$Pattern,
        [string]$Message = ''
    )
    if ($Actual -match $Pattern) {
        $prefix = ''
        if ($Message -ne '') { $prefix = $Message + ' ' }
        throw ('{0}<{1}> seharusnya TIDAK cocok dengan <{2}>.' -f $prefix, $Actual, $Pattern)
    }
}

function Assert-Throws {
    param(
        [scriptblock]$Script,
        [string]$Message = 'Script seharusnya melempar error.'
    )
    $threw = $false
    try { & $Script } catch { $threw = $true }
    if (-not $threw) { throw $Message }
}

# Versi mayor Pester yang sedang berjalan (0 bila tidak terdeteksi).
function Get-PesterMajorVersion {
    $module = Get-Module -Name Pester -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($module) { return [int]$module.Version.Major }
    return 0
}

# Daftar file yang wajib ada di repositori.
function Get-RequiredFiles {
    return @(
        'Menu.cmd'
        'Menu.ps1'
        'README.md'
        'README.en.md'
        'LICENSE'
        'VERSION'
        'CHANGELOG.md'
        '.gitignore'
        '.editorconfig'
        'PSScriptAnalyzerSettings.psd1'
        'tools\dev\Test-Scripts.ps1'
        'tools\03-Test-PrinterShare.ps1'
        'tools\04-Fix-LegacyCompat.ps1'
        'tools\05-Rollback.ps1'
        'tools\05-Rollback-Win7.ps1'
        'host\Win7\01-Sharing-Win7.ps1'
        'host\Win10\01-Sharing-Win10.ps1'
        'host\Win11\01-Sharing-Win11.ps1'
        'client\Win7\02-Connect-Win7.cmd'
        'client\Win7\02-Connect-Win7.ps1'
        'client\Win10\02-Connect-Win10.ps1'
        'client\Win11\02-Connect-Win11.ps1'
        '.github\workflows\ci.yml'
    )
}

# Menjalankan tools\dev\Test-Scripts.ps1 di proses terpisah dan mengembalikan exit code.
function Invoke-QualityChecker {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $checker = Join-Path $RepoRoot 'tools\dev\Test-Scripts.ps1'
    $exe = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($exe) {
        & $exe.Source -NoProfile -ExecutionPolicy Bypass -File $checker *> $null
    }
    else {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $checker *> $null
    }
    return $LASTEXITCODE
}
