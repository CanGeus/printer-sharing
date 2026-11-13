#Requires -Version 2.0
<#
.SYNOPSIS
    Diagnosa read-only untuk masalah sharing printer.

.DESCRIPTION
    Memeriksa semua titik yang biasanya membuat share printer gagal:
    port SMB/RPC, layanan, firewall, konfigurasi SMB, nilai registry
    kompatibilitas, keberadaan share, dan tipe driver.

    Aman dijalankan kapan saja - tidak mengubah apa pun.
    Kompatibel dengan PowerShell 2.0 (Windows 7) dan 5.1 (Windows 10/11).

.PARAMETER Server
    Host printer. Default: komputer lokal. Jalankan di host DAN di klien
    untuk perbandingan hasil.

.PARAMETER ShareName
    Nama share printer yang ingin diverifikasi.

.PARAMETER PrinterName
    Nama printer lokal (untuk cek driver). Opsional.

.EXAMPLE
    .\03-Test-PrinterShare.ps1

.EXAMPLE
    .\03-Test-PrinterShare.ps1 -Server PC-HOST -ShareName HP-L3110

.EXAMPLE
    .\03-Test-PrinterShare.ps1 -Server PC-HOST -ShareName HP-L3110 -PrinterName "HP LaserJet M1136 MFP"
#>
[CmdletBinding()]
param(
    [string]$Server = $env:COMPUTERNAME,
    [string]$ShareName,
    [string]$PrinterName
)

$ErrorActionPreference = 'Continue'

$script:Checks = New-Object System.Collections.ArrayList
$script:Counter = @{ OK = 0; WARN = 0; FAIL = 0; SKIP = 0; INFO = 0 }

function Add-Check {
    param(
        [string]$Name,
        [ValidateSet('OK', 'WARN', 'FAIL', 'SKIP', 'INFO')][string]$Status,
        [string]$Detail,
        [string]$Hint
    )
    [void]$script:Checks.Add((New-Object PSObject -Property @{
        Check  = $Name
        Status = $Status
        Detail = $Detail
        Hint   = $Hint
    }))
    $script:Counter[$Status] = $script:Counter[$Status] + 1

    $color = 'Gray'
    if ($Status -eq 'OK')   { $color = 'Green' }
    if ($Status -eq 'WARN') { $color = 'Yellow' }
    if ($Status -eq 'FAIL') { $color = 'Red' }
    if ($Status -eq 'SKIP') { $color = 'DarkGray' }

    $line = '  [{0,-4}] {1}' -f $Status, $Name
    if ($Detail) { $line = $line + ' : ' + $Detail }
    Write-Host $line -ForegroundColor $color
    if ($Hint -and $Status -ne 'OK' -and $Status -ne 'INFO') {
        Write-Host ('         -> ' + $Hint) -ForegroundColor DarkYellow
    }
}

function Test-TcpPort {
    param([string]$Computer, [int]$Port, [int]$TimeoutMs = 1500)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($Computer, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return $false }
        $client.EndConnect($async)
        return $true
    }
    catch { return $false }
    finally { try { $client.Close() } catch { } }
}

function Get-RegValue {
    param([string]$Path, [string]$Name)
    $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $null }
    return $item.$Name
}

function Has-Command2 {
    param([string]$Name)
    if (Get-Command $Name -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isAdmin = Test-IsAdmin

# ----------------------------------------------------------------------------
$isLocal = $false
if ($Server -eq '.' -or $Server -eq 'localhost' -or $Server -eq '127.0.0.1' -or $Server -eq $env:COMPUTERNAME) {
    $isLocal = $true
    $Server = $env:COMPUTERNAME
}

$osArch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $osArch = $env:PROCESSOR_ARCHITEW6432 }

Write-Host ''
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host (' Diagnosa share printer  ->  {0}' -f $Server) -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host ''

$ver = [System.Environment]::OSVersion.Version
Add-Check -Name 'Klien' -Status 'INFO' -Detail ('Windows {0}.{1} build {2} ({3}), PowerShell {4}' -f $ver.Major, $ver.Minor, $ver.Build, $osArch, $PSVersionTable.PSVersion)
Add-Check -Name 'Mode pemeriksaan' -Status 'INFO' -Detail $(if ($isLocal) { 'LOKAL (script ini jalan di host)' } else { 'REMOTE (script ini jalan di klien)' })

# --- 1. Port -----------------------------------------------------------------
Write-Host ''
Write-Host ' [ Jaringan ]' -ForegroundColor Cyan

if (Test-TcpPort -Computer $Server -Port 445) {
    Add-Check -Name 'Port 445 (SMB)' -Status 'OK' -Detail 'Terbuka'
}
else {
    Add-Check -Name 'Port 445 (SMB)' -Status 'FAIL' -Detail 'Tertutup / tidak terjangkau' -Hint 'Host: cek firewall grup File and Printer Sharing + profil Private'
}

if (Test-TcpPort -Computer $Server -Port 135) {
    Add-Check -Name 'Port 135 (RPC)' -Status 'OK' -Detail 'Terbuka'
}
else {
    Add-Check -Name 'Port 135 (RPC)' -Status 'WARN' -Detail 'Tertutup' -Hint 'Instalasi driver jarak jauh akan gagal; share tetap bisa dipakai bila driver sudah ada'
}

if ($isLocal) {
    $listen139 = Test-TcpPort -Computer '127.0.0.1' -Port 139
    if ($listen139) { Add-Check -Name 'Port 139 (NetBIOS)' -Status 'OK' -Detail 'Listening' }
    else { Add-Check -Name 'Port 139 (NetBIOS)' -Status 'INFO' -Detail 'Tidak listening (normal bila NetBIOS dimatikan)' }
}

# --- 2. Layanan --------------------------------------------------------------
Write-Host ''
Write-Host ' [ Layanan ]' -ForegroundColor Cyan

if ($isLocal) {
    foreach ($svcName in @('Spooler', 'LanmanServer', 'FDResPub', 'SSDPSRV')) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if (-not $svc) {
            Add-Check -Name ('Layanan ' + $svcName) -Status 'WARN' -Detail 'Tidak ada'
            continue
        }
        if ($svc.Status -eq 'Running') {
            Add-Check -Name ('Layanan ' + $svcName) -Status 'OK' -Detail 'Running'
        }
        else {
            $hint = 'Start-Service ' + $svcName
            Add-Check -Name ('Layanan ' + $svcName) -Status 'FAIL' -Detail ([string]$svc.Status) -Hint $hint
        }
    }
}
else {
    Add-Check -Name 'Layanan' -Status 'SKIP' -Detail 'Tidak bisa dicek dari jarak jauh - jalankan script ini di host juga'
}

# --- 3. Firewall -------------------------------------------------------------
Write-Host ''
Write-Host ' [ Firewall ]' -ForegroundColor Cyan

if ($isLocal) {
    if (-not $isAdmin) {
        Add-Check -Name 'Firewall' -Status 'SKIP' -Detail 'Butuh Administrator untuk membaca rule firewall' -Hint 'Jalankan ulang script ini sebagai Administrator'
    }
    elseif (Has-Command2 'Get-NetFirewallRule') {
        $fwGroups = @(
            @{ Label = 'File and Printer Sharing'; Display = 'File and Printer Sharing'; Id = '@FirewallAPI.dll,-28502' },
            @{ Label = 'Network Discovery';        Display = 'Network Discovery';        Id = '@FirewallAPI.dll,-32752' }
        )
        foreach ($group in $fwGroups) {
            $rules = @(Get-NetFirewallRule -Group $group.Id -ErrorAction SilentlyContinue)
            if ($rules.Count -eq 0) {
                $rules = @(Get-NetFirewallRule -DisplayGroup $group.Display -ErrorAction SilentlyContinue)
            }
            if ($rules.Count -eq 0) {
                Add-Check -Name ('Rule grup ' + $group.Label) -Status 'WARN' -Detail 'Grup tidak ditemukan'
                continue
            }
            $enabled = @($rules | Where-Object { [string]$_.Enabled -eq 'True' })
            if ($enabled.Count -gt 0) {
                Add-Check -Name ('Rule grup ' + $group.Label) -Status 'OK' -Detail ('{0} dari {1} rule aktif' -f $enabled.Count, $rules.Count)
            }
            else {
                Add-Check -Name ('Rule grup ' + $group.Label) -Status 'FAIL' -Detail 'Semua nonaktif' -Hint 'Jalankan 01-Setup-PrinterHost.ps1 atau Enable-NetFirewallRule'
            }
        }
        $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
        foreach ($p in $profiles) {
            if ([string]$p.NetworkCategory -eq 'Private') {
                Add-Check -Name ('Profil ' + $p.Name) -Status 'OK' -Detail 'Private'
            }
            else {
                Add-Check -Name ('Profil ' + $p.Name) -Status 'FAIL' -Detail ([string]$p.NetworkCategory) -Hint ('Set-NetConnectionProfile -InterfaceIndex {0} -NetworkCategory Private' -f $p.InterfaceIndex)
            }
        }
    }
    else {
        Add-Check -Name 'Firewall' -Status 'SKIP' -Detail 'Cmdlet NetFirewall tidak tersedia (Windows 7?)'
    }
}
else {
    Add-Check -Name 'Firewall' -Status 'SKIP' -Detail 'Tidak bisa dicek dari jarak jauh'
}

# --- 4. SMB ------------------------------------------------------------------
Write-Host ''
Write-Host ' [ Konfigurasi SMB ]' -ForegroundColor Cyan

if ($isLocal -and (Has-Command2 'Get-SmbServerConfiguration')) {
    $smb = Get-SmbServerConfiguration
    if ($smb.EnableSMB2Protocol) {
        Add-Check -Name 'SMB2' -Status 'OK' -Detail 'Aktif (cukup untuk Windows 7)'
    }
    else {
        Add-Check -Name 'SMB2' -Status 'FAIL' -Detail 'Nonaktif' -Hint 'Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force'
    }
    if ($smb.EnableSMB1Protocol) {
        Add-Check -Name 'SMB1' -Status 'WARN' -Detail 'Aktif' -Hint 'Tidak perlu untuk Win7; sebaiknya dimatikan'
    }
    else {
        Add-Check -Name 'SMB1' -Status 'OK' -Detail 'Nonaktif'
    }
}
else {
    Add-Check -Name 'Konfigurasi SMB' -Status 'SKIP' -Detail 'Hanya bisa dicek lokal'
}

# --- 5. Registry kompatibilitas ----------------------------------------------
Write-Host ''
Write-Host ' [ Registry kompatibilitas ]' -ForegroundColor Cyan

if ($isLocal) {
    $rpc = Get-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' -Name 'RpcAuthnLevelPrivacyEnabled'
    if ($null -eq $rpc) {
        Add-Check -Name 'RpcAuthnLevelPrivacyEnabled' -Status 'WARN' -Detail 'Tidak diset (perilaku ketat/default)' -Hint 'Bila klien Win7 gagal 0x0000011b: jalankan 01 dengan -AllowLegacyWin7'
    }
    elseif ([int]$rpc -eq 0) {
        Add-Check -Name 'RpcAuthnLevelPrivacyEnabled' -Status 'OK' -Detail '0 (klien lama diizinkan)'
    }
    else {
        Add-Check -Name 'RpcAuthnLevelPrivacyEnabled' -Status 'WARN' -Detail ([string]$rpc) -Hint 'Set 0 lewat 01 -AllowLegacyWin7 untuk mengatasi 0x0000011b'
    }

    $pnp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
    $restr = Get-RegValue -Path $pnp -Name 'RestrictDriverInstallationToAdministrators'
    if ($null -ne $restr -and [int]$restr -eq 0) {
        Add-Check -Name 'Point and Print' -Status 'OK' -Detail 'RestrictDriverInstallationToAdministrators = 0'
    }
    else {
        Add-Check -Name 'Point and Print' -Status 'INFO' -Detail 'Kebijakan default/ketat'
    }

    $guest = Get-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'AllowInsecureGuestAuth'
    if ($null -ne $guest -and [int]$guest -eq 1) {
        Add-Check -Name 'AllowInsecureGuestAuth' -Status 'OK' -Detail '1'
    }
    else {
        Add-Check -Name 'AllowInsecureGuestAuth' -Status 'INFO' -Detail 'Tidak aktif (butuh akun berpassword)'
    }
}
else {
    Add-Check -Name 'Registry kompatibilitas' -Status 'SKIP' -Detail 'Hanya bisa dicek lokal'
}

# --- 6. Share printer --------------------------------------------------------
Write-Host ''
Write-Host ' [ Share printer ]' -ForegroundColor Cyan

$shareFound = $false
$driverName = $null
$driverMajor = $null

if ($isLocal) {
    if (Has-Command2 'Get-Printer') {
        $allPrinters = @(Get-Printer)
        if ($PrinterName) {
            $allPrinters = @($allPrinters | Where-Object { $_.Name -eq $PrinterName })
        }
        $shared = @($allPrinters | Where-Object { $_.Shared -eq $true })
        foreach ($p in $shared) {
            Add-Check -Name ('Printer shared: ' + $p.Name) -Status 'OK' -Detail ('ShareName=' + $p.ShareName + ', Port=' + $p.PortName)
            if ($ShareName -and $p.ShareName -eq $ShareName) { $shareFound = $true; $driverName = $p.DriverName }
            elseif (-not $ShareName) { $shareFound = $true; $driverName = $p.DriverName }
            if (Has-Command2 'Get-PrinterDriver') {
                $drv = Get-PrinterDriver -Name $p.DriverName -ErrorAction SilentlyContinue
                if ($drv) {
                    $driverMajor = $drv.MajorVersion
                    if ($drv.MajorVersion -eq 4) {
                        Add-Check -Name 'Tipe driver' -Status 'WARN' -Detail ('{0} = Type 4' -f $p.DriverName) -Hint 'Type 4 tidak bisa dipakai klien Win7 - ganti ke driver Type 3'
                    }
                    else {
                        Add-Check -Name 'Tipe driver' -Status 'OK' -Detail ('{0} = Type {1}' -f $p.DriverName, $drv.MajorVersion)
                    }
                }
            }
        }
        if ($shared.Count -eq 0) {
            if ($PrinterName) {
                Add-Check -Name 'Printer shared' -Status 'FAIL' -Detail ('"{0}" tidak di-share' -f $PrinterName) -Hint 'Jalankan 01-Setup-PrinterHost.ps1 -PrinterName "<nama>"'
            }
            else {
                Add-Check -Name 'Printer shared' -Status 'FAIL' -Detail 'Tidak ada printer yang di-share' -Hint 'Jalankan 01-Setup-PrinterHost.ps1'
            }
        }
        elseif ($ShareName -and -not $shareFound) {
            Add-Check -Name 'Share name' -Status 'FAIL' -Detail ('"' + $ShareName + '" tidak ditemukan') -Hint 'Cek nama share yang benar di output 01'
        }
        elseif ($ShareName) {
            Add-Check -Name 'Share name' -Status 'OK' -Detail ('"' + $ShareName + '" cocok')
        }
    }
    else {
        $wmiPrinters = @(Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue)
        $shared = @($wmiPrinters | Where-Object { $_.Shared -eq $true })
        foreach ($p in $shared) {
            Add-Check -Name ('Printer shared: ' + $p.Name) -Status 'OK' -Detail ('ShareName=' + $p.ShareName)
            if ($ShareName -and $p.ShareName -eq $ShareName) { $shareFound = $true }
        }
        if ($shared.Count -eq 0) {
            Add-Check -Name 'Printer shared' -Status 'FAIL' -Detail 'Tidak ada printer yang di-share'
        }
    }
}
else {
    try {
        $remotePrinters = @(Get-WmiObject -Class Win32_Printer -ComputerName $Server -ErrorAction Stop)
        $shared = @($remotePrinters | Where-Object { $_.Shared -eq $true })
        foreach ($p in $shared) {
            if (-not $ShareName -or $p.ShareName -eq $ShareName) {
                Add-Check -Name ('Printer shared: ' + $p.ShareName) -Status 'OK' -Detail ('Name=' + $p.Name)
                $shareFound = $true
            }
        }
        if (-not $shareFound) {
            Add-Check -Name 'Printer shared' -Status 'FAIL' -Detail 'Tidak ditemukan lewat WMI' -Hint ('Coba: net view \\{0}' -f $Server)
        }
    }
    catch {
        Add-Check -Name 'Printer shared' -Status 'WARN' -Detail 'WMI remote diblokir' -Hint 'Coba manual: net view \\HOST'
    }
}

# --- 7. Akses UNC ------------------------------------------------------------
Write-Host ''
Write-Host ' [ Akses UNC ]' -ForegroundColor Cyan

if ($ShareName) {
    $unc = '\\{0}\{1}' -f $Server, $ShareName
    Add-Check -Name 'Target' -Status 'INFO' -Detail $unc

    $view = @()
    if ($isLocal) {
        Add-Check -Name 'Share terlihat dari klien' -Status 'INFO' -Detail 'Dijalankan di host - tes browsing dilewati'
    }
    else {
        try { $view = @(net view ('\\' + $Server) 2>&1) } catch { }
        $viewOk = ($LASTEXITCODE -eq 0)
        $viewText = ($view | Out-String)
        if ($viewText -match [regex]::Escape($ShareName)) {
            Add-Check -Name 'Share terlihat dari klien' -Status 'OK' -Detail 'net view menemukan share'
        }
        elseif (-not $viewOk) {
            Add-Check -Name 'Share terlihat dari klien' -Status 'INFO' -Detail 'net view dibatasi (normal di Win10/11)'
        }
        else {
            Add-Check -Name 'Share terlihat dari klien' -Status 'WARN' -Detail 'Tidak terlihat di net view' -Hint 'Normal bila SMB browsing dibatasi; akses langsung lewat UNC tetap bisa'
        }
    }
}
else {
    Add-Check -Name 'Akses UNC' -Status 'INFO' -Detail 'Tambahkan -ShareName <nama> untuk menguji share tertentu'
}

# ----------------------------------------------------------------------------
# Ringkasan
# ----------------------------------------------------------------------------
Write-Host ''
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host (' OK={0}  WARN={1}  FAIL={2}  SKIP={3}' -f $script:Counter.OK, $script:Counter.WARN, $script:Counter.FAIL, $script:Counter.SKIP) -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan

if ($script:Counter.FAIL -eq 0) {
    Write-Host ''
    Write-Host ' Tidak ada kegagalan kritis.' -ForegroundColor Green
    if ($script:Counter.WARN -gt 0) {
        Write-Host ' Ada peringatan - baca baris WARN di atas.' -ForegroundColor Yellow
    }
}
else {
    Write-Host ''
    Write-Host (' Ada {0} kegagalan. Perbaiki yang paling atas dulu.' -f $script:Counter.FAIL) -ForegroundColor Red
}

Write-Host ''

if ($script:Counter.FAIL -gt 0) { exit 1 } else { exit 0 }
