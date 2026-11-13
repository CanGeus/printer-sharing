#Requires -Version 2.0
<#
.SYNOPSIS
    Membalikkan perubahan 01-Sharing-Win7.ps1.

.DESCRIPTION
    Membaca file journal teks yang dibuat script host Windows 7, lalu
    mengembalikan network location, rule firewall, startup service,
    SMB2, dan status share printer.

.PARAMETER JournalFile
    File Win7-backup-*.txt. Default: yang terbaru di
    C:\ProgramData\PrinterShare\logs

.PARAMETER Force
    Tanpa konfirmasi.

.EXAMPLE
    .\05-Rollback-Win7.ps1

.EXAMPLE
    .\05-Rollback-Win7.ps1 -JournalFile "C:\ProgramData\PrinterShare\logs\Win7-backup-20260101-120000.txt" -Force
#>
[CmdletBinding()]
param(
    [string]$JournalFile,
    [switch]$Force,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$script:LogRoot = Join-Path $env:ProgramData 'PrinterShare\logs'

function Write-Ok2   { param([string]$T) Write-Host ('  [OK]   ' + $T) -ForegroundColor Green }
function Write-Warn3 { param([string]$T) Write-Host ('  [WARN] ' + $T) -ForegroundColor Yellow }

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Harus dijalankan sebagai Administrator.' -ForegroundColor Red
    exit 1
}

if (-not $JournalFile) {
    $latest = $null
    $files = @(Get-ChildItem -Path $script:LogRoot -Filter 'Win7-backup-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($files.Count -gt 0) { $latest = $files[0] }
    if (-not $latest) {
        Write-Host 'Tidak ada journal di C:\ProgramData\PrinterShare\logs' -ForegroundColor Yellow
        exit 2
    }
    $JournalFile = $latest.FullName
}

if (-not (Test-Path -LiteralPath $JournalFile)) {
    Write-Host ('Journal tidak ditemukan: {0}' -f $JournalFile) -ForegroundColor Red
    exit 2
}

Write-Host ''
Write-Host '=========== ROLLBACK HOST WINDOWS 7 ===========' -ForegroundColor Cyan
Write-Host ('Journal: {0}' -f $JournalFile) -ForegroundColor Gray
Write-Host ''

if (-not $Force) {
    $answer = Read-Host 'Kembalikan semua perubahan? Ketik YA'
    if ($answer -ne 'YA') { Write-Host 'Dibatalkan.' -ForegroundColor Yellow; exit 0 }
}

$lines = @(Get-Content -LiteralPath $JournalFile)
$shareName = $null

foreach ($line in $lines) {
    if ($line -match '^SHARENAME=(.+)$') { $shareName = $matches[1] }
}

foreach ($line in $lines) {

    if ($line -match '^PROFILE=([^\|]+)\|(\d+)$') {
        $guid = $matches[1]
        $cat = [int]$matches[2]
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles\' + $guid
        if (Test-Path -LiteralPath $key) {
            if ($WhatIf) { Write-Warn3 ('WhatIf: profile {0} -> {1}' -f $guid, $cat) }
            else { Set-ItemProperty -Path $key -Name Category -Value $cat; Write-Ok2 ('profil {0} -> Category {1}' -f $guid, $cat) }
        }
    }

    elseif ($line -match '^FIREWALL=(.+)$') {
        $ruleName = $matches[1]
        if ($WhatIf) { Write-Warn3 ('WhatIf: disable rule {0}' -f $ruleName) }
        else {
            try {
                $fw = New-Object -ComObject HNetCfg.FwPolicy2
                foreach ($rule in $fw.Rules) {
                    if ([string]$rule.Name -eq $ruleName -and $rule.Enabled) { $rule.Enabled = $false }
                }
                Write-Ok2 ('rule dinonaktifkan: {0}' -f $ruleName)
            }
            catch { Write-Warn3 ('gagal rule {0}' -f $ruleName) }
        }
    }

    elseif ($line -match '^SERVICE=([^\|]+)\|([^\|]+)\|(.+)$') {
        $name = $matches[1]
        $start = $matches[2]
        $status = $matches[3]
        if ($WhatIf) { Write-Warn3 ('WhatIf: service {0} -> {1}' -f $name, $start) }
        else {
            & sc.exe config $name 'start=' $start | Out-Null
            if ($status -eq 'Stopped') { & sc.exe stop $name | Out-Null }
            else { & sc.exe start $name | Out-Null }
            Write-Ok2 ('service {0} -> {1}' -f $name, $start)
        }
    }

    elseif ($line -match '^SMB2=(\d+)$') {
        $val = [int]$matches[1]
        $key = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
        if ($WhatIf) { Write-Warn3 ('WhatIf: SMB2 = {0}' -f $val) }
        else {
            New-ItemProperty -Path $key -Name 'SMB2' -Value $val -PropertyType DWord -Force | Out-Null
            Write-Ok2 ('SMB2 = {0}' -f $val)
        }
    }

    elseif ($line -match '^PRINTER=([^\|]+)\|([^\|]+)\|(.*)$') {
        $pname = $matches[1]
        $wasShared = $matches[2]
        if ($wasShared -ne 'True') {
            if ($WhatIf) { Write-Warn3 ('WhatIf: unshare {0}' -f $pname) }
            else {
                if ($shareName) { & net.exe share ($shareName) '/delete' | Out-Null }
                & net.exe share ($shareName + '=' + $pname) '/delete' | Out-Null
                Write-Ok2 ('share dilepas: {0}' -f $pname)
            }
        }
        else {
            Write-Ok2 ('printer {0} memang sudah di-share sebelumnya - dibiarkan' -f $pname)
        }
    }
}

Write-Host ''
Write-Host 'Rollback host Windows 7 selesai.' -ForegroundColor Cyan
Write-Host 'Restart komputer bila network location tidak langsung berubah.' -ForegroundColor Gray
Write-Host ''

exit 0
