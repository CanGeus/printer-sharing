#Requires -Version 5.1
<#
.SYNOPSIS
    Membalikkan perubahan yang dibuat oleh 01-Setup-PrinterHost.ps1
    dan 04-Fix-LegacyCompat.ps1.

.DESCRIPTION
    Membaca file backup JSON, lalu mengembalikan:
      - status share printer
      - nilai registry (RPC / Point and Print / guest)
      - startup type dan status layanan
      - rule firewall yang tadi diaktifkan
      - kategori profil jaringan

    Tanpa -BackupFile, dipakai file backup terbaru di folder .\logs.

.PARAMETER BackupFile
    Path file JSON. Default: backup terbaru di folder logs.

.PARAMETER Force
    Tidak meminta konfirmasi.

.EXAMPLE
    .\05-Rollback.ps1

.EXAMPLE
    .\05-Rollback.ps1 -BackupFile ".\logs\backup-20260101-120000.json" -Force
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$BackupFile,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$script:LogDir = Join-Path $env:ProgramData 'PrinterShare\logs'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Harus dijalankan sebagai Administrator.' -ForegroundColor Red
    exit 1
}

if (-not $BackupFile) {
    $latest = Get-ChildItem -Path $script:LogDir -Filter 'backup-*.json' -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Host ''
        Write-Host 'Tidak ada file backup di C:\ProgramData\PrinterShare\logs.' -ForegroundColor Yellow
        Write-Host 'Tidak ada yang bisa di-rollback.' -ForegroundColor Yellow
        Write-Host ''
        exit 2
    }
    $BackupFile = $latest.FullName
}

if (-not (Test-Path -LiteralPath $BackupFile)) {
    Write-Host ('File backup tidak ditemukan: {0}' -f $BackupFile) -ForegroundColor Red
    exit 2
}

$data = Get-Content -LiteralPath $BackupFile -Raw | ConvertFrom-Json

Write-Host ''
Write-Host '=============== ROLLBACK ===============' -ForegroundColor Cyan
Write-Host ('File     : {0}' -f $BackupFile) -ForegroundColor Gray
Write-Host ('Dibuat   : {0}' -f $data.Created) -ForegroundColor Gray
Write-Host ('Komputer : {0}' -f $data.Computer) -ForegroundColor Gray
Write-Host ''

if (-not $Force) {
    $answer = Read-Host 'Kembalikan semua perubahan? Ketik YA untuk lanjut'
    if ($answer -ne 'YA') {
        Write-Host 'Dibatalkan.' -ForegroundColor Yellow
        exit 0
    }
}

$log = New-Object System.Collections.ArrayList
function Add-Log {
    param([string]$Text)
    [void]$log.Add($Text)
    Write-Host ('  ' + $Text) -ForegroundColor DarkGray
}

# --- 1. Registry -------------------------------------------------------------
Write-Host '[1/5] Registry' -ForegroundColor Yellow
$regTouched = $false
foreach ($r in @($data.Registry)) {
    if (-not $r.Path -or -not $r.Name) { continue }
    try {
        if ($r.Existed) {
            $type = 'String'
            if ($r.OldType) { $type = [string]$r.OldType }
            if (-not (Test-Path -LiteralPath $r.Path)) { New-Item -Path $r.Path -Force | Out-Null }
            New-ItemProperty -LiteralPath $r.Path -Name $r.Name -Value $r.OldValue -PropertyType $type -Force | Out-Null
            Add-Log ('Restore {0}\{1} = {2}' -f $r.Path, $r.Name, $r.OldValue)
        }
        else {
            Remove-ItemProperty -LiteralPath $r.Path -Name $r.Name -ErrorAction SilentlyContinue
            Add-Log ('Hapus {0}\{1}' -f $r.Path, $r.Name)
        }
        if ($r.Path -like '*\Control\Print*') { $regTouched = $true }
    }
    catch {
        Add-Log ('GAGAL {0}\{1}: {2}' -f $r.Path, $r.Name, $_.Exception.Message)
    }
}
if (@($data.Registry).Count -eq 0) { Add-Log 'Tidak ada perubahan registry yang dicatat' }

# --- 2. Printer --------------------------------------------------------------
Write-Host '[2/5] Share printer' -ForegroundColor Yellow
foreach ($p in @($data.Printers)) {
    if (-not $p.Name) { continue }
    $current = Get-Printer -Name $p.Name -ErrorAction SilentlyContinue
    if (-not $current) {
        Add-Log ('Printer {0} sudah tidak ada - dilewati' -f $p.Name)
        continue
    }
    try {
        if ($p.Shared -eq $true) {
            if ($p.ShareName) {
                Set-Printer -Name $p.Name -Shared $true -ShareName $p.ShareName
                Add-Log ('Share {0} dipulihkan ke {1}' -f $p.Name, $p.ShareName)
            }
        }
        else {
            Set-Printer -Name $p.Name -Shared $false
            Add-Log ('Share {0} dimatikan' -f $p.Name)
        }
    }
    catch {
        Add-Log ('GAGAL unshare {0}: {1}' -f $p.Name, $_.Exception.Message)
    }
}
if (@($data.Printers).Count -eq 0) { Add-Log 'Tidak ada perubahan printer yang dicatat' }

# --- 3. Firewall -------------------------------------------------------------
Write-Host '[3/5] Firewall' -ForegroundColor Yellow
$fwCount = 0
if (Get-Command Disable-NetFirewallRule -ErrorAction SilentlyContinue) {
    foreach ($r in @($data.FirewallRules)) {
        if (-not $r.Name) { continue }
        try {
            Disable-NetFirewallRule -Name $r.Name -ErrorAction Stop
            $fwCount++
        }
        catch { }
    }
    Add-Log ('{0} rule firewall dikembalikan ke nonaktif' -f $fwCount)
}
else {
    Add-Log 'Cmdlet firewall tidak tersedia - dilewati'
}

# --- 4. Layanan --------------------------------------------------------------
Write-Host '[4/5] Layanan' -ForegroundColor Yellow
foreach ($s in @($data.Services)) {
    if (-not $s.Name) { continue }
    $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
    if (-not $svc) { continue }
    try {
        if ($s.StartType) {
            Set-Service -Name $s.Name -StartupType $s.StartType
            Add-Log ('{0} startup -> {1}' -f $s.Name, $s.StartType)
        }
        if ($s.Status -eq 'Stopped' -and $svc.Status -eq 'Running') {
            Stop-Service -Name $s.Name -Force
            Add-Log ('{0} dihentikan' -f $s.Name)
        }
        elseif ($s.Status -eq 'Running' -and $svc.Status -ne 'Running') {
            Start-Service -Name $s.Name
            Add-Log ('{0} dijalankan' -f $s.Name)
        }
    }
    catch {
        Add-Log ('GAGAL layanan {0}: {1}' -f $s.Name, $_.Exception.Message)
    }
}
if (@($data.Services).Count -eq 0) { Add-Log 'Tidak ada perubahan layanan yang dicatat' }

# --- 5. Profil jaringan ------------------------------------------------------
Write-Host '[5/5] Profil jaringan' -ForegroundColor Yellow
foreach ($n in @($data.NetworkProfiles)) {
    if (-not $n.InterfaceIndex -or -not $n.NetworkCategory) { continue }
    try {
        $curr = Get-NetConnectionProfile -InterfaceIndex $n.InterfaceIndex -ErrorAction SilentlyContinue
        if ($curr -and [string]$curr.NetworkCategory -ne [string]$n.NetworkCategory) {
            Set-NetConnectionProfile -InterfaceIndex $n.InterfaceIndex -NetworkCategory $n.NetworkCategory
            Add-Log ('Interface {0} -> {1}' -f $n.InterfaceIndex, $n.NetworkCategory)
        }
    }
    catch {
        Add-Log ('GAGAL profil {0}: {1}' -f $n.InterfaceIndex, $_.Exception.Message)
    }
}
if (@($data.NetworkProfiles).Count -eq 0) { Add-Log 'Tidak ada perubahan profil jaringan yang dicatat' }

# --- Restart spooler ---------------------------------------------------------
if ($regTouched) {
    try {
        Restart-Service -Name Spooler -Force
        Add-Log 'Spooler direstart'
    }
    catch {
        Add-Log ('GAGAL restart spooler: {0}' -f $_.Exception.Message)
    }
}

Write-Host ''
Write-Host 'Rollback selesai.' -ForegroundColor Cyan
Write-Host ('Total aksi: {0}' -f $log.Count) -ForegroundColor Gray
Write-Host ''
Write-Host 'Kalau ada langkah yang gagal, cek pesannya di atas atau restart komputer.' -ForegroundColor Gray
Write-Host ''

exit 0
