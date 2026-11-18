#Requires -Version 5.1
<#
.SYNOPSIS
    Menjalankan seluruh test Pester di folder tests\.

.DESCRIPTION
    Berfungsi di Pester 3.x (bawaan Windows PowerShell 5.1) maupun Pester 4/5.

    Keluar dengan kode:
      0 - semua test lulus
      1 - ada test yang gagal
      2 - Pester tidak terpasang

.EXAMPLE
    .\tests\Run-Tests.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host 'Pester tidak terpasang.' -ForegroundColor Red
    Write-Host 'Install-Module Pester -Scope CurrentUser -Force' -ForegroundColor Yellow
    exit 2
}

Import-Module Pester -Force
$pesterVersion = (Get-Module Pester).Version
Write-Host ('Pester ' + $pesterVersion) -ForegroundColor Cyan
Write-Host ''

$params = @{
    Path     = $PSScriptRoot
    PassThru = $true
}
if ($pesterVersion.Major -ge 5) {
    $params['Output'] = 'Detailed'
}

$result = Invoke-Pester @params

Write-Host ''
if ($result.FailedCount -gt 0) {
    Write-Host ('HASIL: GAGAL ({0} dari {1} test gagal)' -f $result.FailedCount, $result.TotalCount) -ForegroundColor Red
    exit 1
}

Write-Host ('HASIL: LULUS ({0} test)' -f $result.PassedCount) -ForegroundColor Green
exit 0
