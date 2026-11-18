#Requires -Version 5.1
<#
.SYNOPSIS
    Fungsi assertion untuk file Pester di folder tests\.

.DESCRIPTION
    Sintaks Should berbeda antar versi Pester:

      - Pester 3.x (bawaan Windows PowerShell 5.1) memakai "Should Be".
      - Pester 4/5 memakai "Should -Be".

    Supaya file test yang sama tetap jalan di kedua versi, test memakai
    helper di bawah ini. Helper melempar exception saat gagal, dan Pester
    melaporkannya sebagai test yang gagal.
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
