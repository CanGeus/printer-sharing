#Requires -Version 2.0
<#
.SYNOPSIS
    HOST Windows 7 - share printer USB agar bisa dipakai PC lain.

.DESCRIPTION
    Dijalankan di PC Windows 7 yang menempel printer (USB).
    Script ini kompatibel PowerShell 2.0.

    Untuk host Windows 10 pakai ..\Win10\01-Sharing-Win10.ps1.
    Untuk host Windows 11 pakai ..\Win11\01-Sharing-Win11.ps1.

    Yang dilakukan:
      1. Network location -> Private (lewat registry NetworkList)
      2. Firewall File and Printer Sharing + Network Discovery (via COM,
         jadi tetap jalan di Windows berbahasa Indonesia)
      3. Layanan Spooler / LanmanServer / FDResPub / SSDPSRV / upnphost
      4. Cek SMB2
      5. Share printer (prncnfg.vbs -> printui -> net share)
      6. Verifikasi

    Perubahan dicatat ke C:\ProgramData\PrinterShare\logs\Win7-backup-*.txt
    dan bisa dibalik dengan tools\05-Rollback-Win7.ps1.

.PARAMETER PrinterName
    Nama printer. Lihat dengan -ListPrinters.

.PARAMETER ShareName
    Nama share. Default dari nama printer, tanpa spasi, maks 12 karakter.

.PARAMETER EnableSMB2
    Menyalakan SMB2 bila di sistem ini dimatikan (jarang terjadi).

.EXAMPLE
    .\01-Sharing-Win7.ps1 -ListPrinters

.EXAMPLE
    .\01-Sharing-Win7.ps1 -PrinterName "EPSON L120 Series" -WhatIf

.EXAMPLE
    .\01-Sharing-Win7.ps1 -PrinterName "EPSON L120 Series"
#>
[CmdletBinding()]
param(
    [string]$PrinterName,
    [string]$ShareName,
    [switch]$EnableSMB2,
    [switch]$SkipNetworkProfile,
    [switch]$SkipFirewall,
    [switch]$ListPrinters,
    [switch]$WhatIf,
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'
$script:LogRoot = Join-Path $env:ProgramData 'PrinterShare\logs'

function Write-Ok   { param([string]$T) Write-Host ('  [OK]   ' + $T) -ForegroundColor Green }
function Write-Warn2{ param([string]$T) Write-Host ('  [WARN] ' + $T) -ForegroundColor Yellow }
function Write-Fail2{ param([string]$T) Write-Host ('  [FAIL] ' + $T) -ForegroundColor Red }
function Write-Info2{ param([string]$T) Write-Host ('  [INFO] ' + $T) -ForegroundColor Cyan }

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PrinterList {
    return @(Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue)
}

$script:Failed = $false
$script:Journal = New-Object System.Collections.ArrayList
function Add-Journal { param([string]$Line) [void]$script:Journal.Add($Line) }

# ----------------------------------------------------------------------------
if ($ListPrinters) {
    Write-Host ''
    Write-Host 'Printer di komputer ini (Windows 7):' -ForegroundColor Cyan
    Get-PrinterList |
        Select-Object Name, DriverName, PortName, Shared, ShareName |
        Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    Write-Host 'Kandidat: PortName USBxxx / LPTx / DOT4 / TCPIP (bukan \\...).' -ForegroundColor Gray
    Write-Host ''
    exit 0
}

if (-not (Test-IsAdmin)) {
    Write-Host ''
    Write-Host 'Jalankan sebagai Administrator (klik kanan -> Run as administrator).' -ForegroundColor Red
    Write-Host ''
    exit 1
}

$ver = [System.Environment]::OSVersion.Version
if (-not ($ver.Major -eq 6 -and $ver.Minor -eq 1)) {
    Write-Host ''
    Write-Host ('Script ini untuk Windows 7. OS terdeteksi: {0}.{1}' -f $ver.Major, $ver.Minor) -ForegroundColor Red
    Write-Host 'Windows 10 -> host\Win10\01-Sharing-Win10.ps1' -ForegroundColor Yellow
    Write-Host 'Windows 11 -> host\Win11\01-Sharing-Win11.ps1' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

if (-not (Test-Path -LiteralPath $script:LogRoot)) {
    New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
}
if (-not $BackupPath) {
    $BackupPath = Join-Path $script:LogRoot ('Win7-backup-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

Write-Host ''
Write-Host '=================================================' -ForegroundColor Cyan
Write-Host ' HOST Windows 7 - Setup share printer' -ForegroundColor Cyan
Write-Host '=================================================' -ForegroundColor Cyan
Write-Host ''

Add-Journal ('COMPUTER=' + $env:COMPUTERNAME)
Add-Journal ('DATE=' + (Get-Date).ToString('s'))

# ----------------------------------------------------------------------------
# 1. Network location -> Private
# ----------------------------------------------------------------------------
Write-Host '[1/5] Network location' -ForegroundColor Yellow
if ($SkipNetworkProfile) {
    Write-Info2 'Dilewati'
}
else {
    $base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles'
    $profiles = @(Get-ChildItem -Path $base -ErrorAction SilentlyContinue)
    if ($profiles.Count -eq 0) {
        Write-Warn2 'Tidak ada profil jaringan tercatat'
    }
    foreach ($p in $profiles) {
        $props = Get-ItemProperty -Path $p.PSPath
        $cat = [int]$props.Category
        $name = [string]$props.ProfileName
        Add-Journal ('PROFILE=' + [string]$props.ProfileGuid + '|' + $cat)
        if ($cat -eq 1) {
            Write-Ok ('{0} sudah Private' -f $name)
        }
        elseif ($WhatIf) {
            Write-Warn2 ('WhatIf: {0} -> Private' -f $name)
        }
        else {
            Set-ItemProperty -Path $p.PSPath -Name Category -Value 1
            Write-Ok ('{0} -> Private' -f $name)
        }
    }
}

# ----------------------------------------------------------------------------
# 2. Firewall via COM (locale-independent)
# ----------------------------------------------------------------------------
Write-Host '[2/5] Firewall' -ForegroundColor Yellow
if ($SkipFirewall) {
    Write-Info2 'Dilewati'
}
else {
    try {
        $fw = New-Object -ComObject HNetCfg.FwPolicy2
        $ids = @('@FirewallAPI.dll,-28502', '@FirewallAPI.dll,-32752')
        $enabled = 0
        foreach ($rule in $fw.Rules) {
            if ($ids -contains [string]$rule.Grouping) {
                if (-not $rule.Enabled) {
                    Add-Journal ('FIREWALL=' + [string]$rule.Name)
                    if (-not $WhatIf) { $rule.Enabled = $true; $enabled++ }
                }
            }
        }
        if ($WhatIf) { Write-Warn2 'WhatIf: rule firewall tidak diubah' }
        elseif ($enabled -gt 0) { Write-Ok ('{0} rule diaktifkan' -f $enabled) }
        else { Write-Ok 'Semua rule sudah aktif' }
    }
    catch {
        Write-Warn2 ('Gagal akses Windows Firewall: {0}' -f $_.Exception.Message)
    }
}

# ----------------------------------------------------------------------------
# 3. Layanan
# ----------------------------------------------------------------------------
Write-Host '[3/5] Layanan' -ForegroundColor Yellow
$services = @(
    @{ Name = 'Spooler';      Start = 'auto'   },
    @{ Name = 'LanmanServer'; Start = 'auto'   },
    @{ Name = 'FDResPub';     Start = 'auto'   },
    @{ Name = 'SSDPSRV';      Start = 'auto'   },
    @{ Name = 'upnphost';     Start = 'demand' }
)
foreach ($s in $services) {
    $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Warn2 ('{0} tidak ada' -f $s.Name); continue }

    $wmi = Get-WmiObject -Class Win32_Service -Filter ("Name='" + $s.Name + "'") -ErrorAction SilentlyContinue
    $curStart = 'demand'
    if ($wmi) {
        if ($wmi.StartMode -eq 'Auto') { $curStart = 'auto' }
        elseif ($wmi.StartMode -eq 'Disabled') { $curStart = 'disabled' }
    }
    Add-Journal ('SERVICE=' + $s.Name + '|' + $curStart + '|' + [string]$svc.Status)

    if ($WhatIf) { Write-Warn2 ('WhatIf: {0}' -f $s.Name); continue }
    if ($curStart -ne $s.Start) {
        & sc.exe config $s.Name 'start=' $s.Start | Out-Null
    }
    if ($svc.Status -ne 'Running') {
        try { Start-Service -Name $s.Name } catch { Write-Warn2 ('{0}: {1}' -f $s.Name, $_.Exception.Message); continue }
    }
    Write-Ok ('{0} berjalan' -f $s.Name)
}

# ----------------------------------------------------------------------------
# 4. SMB2
# ----------------------------------------------------------------------------
Write-Host '[4/5] SMB2' -ForegroundColor Yellow
$smbKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
$smb2 = Get-ItemProperty -Path $smbKey -Name 'SMB2' -ErrorAction SilentlyContinue
$smb2Val = 1
if ($null -ne $smb2) { $smb2Val = [int]$smb2.SMB2 }
Add-Journal ('SMB2=' + $smb2Val)

if ($smb2Val -eq 0) {
    if ($EnableSMB2) {
        if ($WhatIf) { Write-Warn2 'WhatIf: SMB2 = 1' }
        else {
            New-ItemProperty -Path $smbKey -Name 'SMB2' -Value 1 -PropertyType DWord -Force | Out-Null
            Write-Ok 'SMB2 diaktifkan (perlu restart)'
        }
    }
    else {
        Write-Warn2 'SMB2 nonaktif - tambahkan -EnableSMB2 (Win7 butuh SMB2 untuk Win10/11)'
    }
}
else {
    Write-Ok 'SMB2 aktif'
}

# ----------------------------------------------------------------------------
# 5. Share printer
# ----------------------------------------------------------------------------
Write-Host '[5/5] Share printer' -ForegroundColor Yellow
$all = Get-PrinterList
$excluded = 'Microsoft Print to PDF|Microsoft XPS|^Fax$|OneNote|Send To'
$candidates = @()
foreach ($p in $all) {
    if ($p.Name -match $excluded) { continue }
    if ([string]$p.PortName -match '^\\\\') { continue }
    $candidates += $p
}

if ($PrinterName) {
    $printer = $null
    foreach ($p in $all) { if ($p.Name -eq $PrinterName) { $printer = $p } }
    if (-not $printer) { Write-Fail2 ('Printer "{0}" tidak ditemukan' -f $PrinterName); exit 1 }
}
elseif ($candidates.Count -eq 1) { $printer = $candidates[0] }
elseif ($candidates.Count -eq 0) { Write-Fail2 'Tidak ada printer lokal'; exit 1 }
else {
    $names = @()
    foreach ($p in $candidates) { $names += $p.Name }
    Write-Fail2 ('Ada {0} printer: {1}' -f $candidates.Count, ($names -join ' | '))
    Write-Info2 'Tentukan satu dengan -PrinterName "<nama>"'
    exit 1
}
Write-Info2 ('Printer: {0}  [{1}]' -f $printer.Name, $printer.PortName)

if (-not $ShareName) {
    $raw = ($printer.Name -replace '[^\w\.\-]', '-') -replace '-{2,}', '-'
    $raw = $raw.Trim('-')
    if ($raw.Length -gt 12) { $raw = $raw.Substring(0, 12).Trim('-') }
    $ShareName = $raw
}
else {
    $ShareName = $ShareName -replace '\s', '-'
}
Add-Journal ('PRINTER=' + $printer.Name + '|' + [string]$printer.Shared + '|' + [string]$printer.ShareName)
Add-Journal ('SHARENAME=' + $ShareName)

$unc = '\\{0}\{1}' -f $env:COMPUTERNAME, $ShareName

if ($printer.Shared -and $printer.ShareName -eq $ShareName) {
    Write-Ok ('Sudah di-share: ' + $unc)
}
elseif ($WhatIf) {
    Write-Warn2 ('WhatIf: share "{0}" sebagai "{1}"' -f $printer.Name, $ShareName)
}
else {
    $done = $false

    # Cara 1: prncnfg.vbs (resmi dari Microsoft, ada di Win7)
    $scriptsRoot = Join-Path $env:windir 'System32\Printing_Admin_Scripts'
    $prncnfg = $null
    if (Test-Path -LiteralPath $scriptsRoot) {
        $found = @(Get-ChildItem -Path $scriptsRoot -Recurse -Filter 'prncnfg.vbs' -ErrorAction SilentlyContinue)
        if ($found.Count -gt 0) { $prncnfg = $found[0].FullName }
    }
    if ($prncnfg) {
        & cscript.exe //nologo $prncnfg -x -p $printer.Name -shared -sharename $ShareName | Out-Null
        Start-Sleep -Seconds 1
        $chk = $null
        foreach ($p in (Get-PrinterList)) { if ($p.Name -eq $printer.Name) { $chk = $p } }
        if ($chk -and $chk.Shared) { $done = $true; Write-Ok 'prncnfg.vbs berhasil' }
    }

    # Cara 2: printui ShareName
    if (-not $done) {
        $arg = 'printui.dll,PrintUIEntry /Xs /n "' + $printer.Name + '" ShareName "' + $ShareName + '"'
        Start-Process -FilePath 'rundll32.exe' -ArgumentList $arg -Wait -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        $chk = $null
        foreach ($p in (Get-PrinterList)) { if ($p.Name -eq $printer.Name) { $chk = $p } }
        if ($chk -and $chk.Shared) { $done = $true; Write-Ok 'printui berhasil' }
    }

    # Cara 3: net share
    if (-not $done) {
        & net.exe share ($ShareName + '=' + $printer.Name) '/GRANT:Everyone,PRINT' | Out-Null
        Start-Sleep -Seconds 1
        $chk = $null
        foreach ($p in (Get-PrinterList)) { if ($p.Name -eq $printer.Name) { $chk = $p } }
        if ($chk -and $chk.Shared) { $done = $true; Write-Ok 'net share berhasil' }
    }

    if (-not $done) {
        Write-Fail2 'Otomatis gagal share. Lakukan manual:'
        Write-Host '     Klik kanan printer -> Printer properties -> tab Sharing' -ForegroundColor Gray
        Write-Host ('     centang "Share this printer", Share name: {0}' -f $ShareName) -ForegroundColor Gray
        $script:Failed = $true
    }
    else {
        Write-Ok ('Di-share sebagai ' + $unc)
    }
}

if (-not $WhatIf) {
    Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# ----------------------------------------------------------------------------
# Verifikasi + ringkasan
# ----------------------------------------------------------------------------
Write-Host ''
Write-Host '================ VERIFIKASI ================' -ForegroundColor Cyan
if ($WhatIf) {
    Write-Info2 'WhatIf - tidak ada verifikasi'
}
else {
    $final = $null
    foreach ($p in (Get-PrinterList)) { if ($p.Name -eq $printer.Name) { $final = $p } }
    if ($final -and $final.Shared) { Write-Ok ('Shared=True, ShareName=' + $final.ShareName) }
    else { Write-Fail2 'Printer belum ter-share'; $script:Failed = $true }

    $netstat = @(netstat -an 2>$null)
    $t445 = $false
    foreach ($line in $netstat) { if ($line -match ':445\s' -and $line -match 'LISTEN') { $t445 = $true } }
    if ($t445) { Write-Ok 'Port 445 listening' }
    else { Write-Fail2 'Port 445 tidak listening'; $script:Failed = $true }
}

Write-Host ''
Write-Host '=========== CARA CONNECT DARI KLIEN ===========' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Klien Windows 7 :  client\Win7\02-Connect-Win7.cmd' -ForegroundColor Yellow
Write-Host ('  {0}' -f $unc) -ForegroundColor Gray
Write-Host 'Klien Windows 10:  client\Win10\02-Connect-Win10.ps1' -ForegroundColor Yellow
Write-Host 'Klien Windows 11:  client\Win11\02-Connect-Win11.ps1' -ForegroundColor Yellow
Write-Host ''

$script:Journal | Set-Content -LiteralPath $BackupPath -Encoding ASCII
Write-Host ('Journal: {0}' -f $BackupPath) -ForegroundColor DarkGray
Write-Host ('Rollback: ..\..\tools\05-Rollback-Win7.ps1 -JournalFile "{0}"' -f $BackupPath) -ForegroundColor DarkGray
Write-Host ''

if ($script:Failed) { exit 1 } else { exit 0 }
