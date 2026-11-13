#Requires -Version 5.1
<#
.SYNOPSIS
    KLIEN Windows 10 - connect ke printer yang di-share PC lain.

.DESCRIPTION
    Dijalankan di PC Windows 10 yang ingin mencetak.
    Host boleh Windows 7, 10, atau 11 - tidak masalah.

    Untuk Windows 11 pakai ..\Win11\02-Connect-Win11.ps1
    Untuk Windows 7 pakai ..\Win7\02-Connect-Win7.cmd

.PARAMETER Server
    Nama komputer atau IP host, tanpa \\ di depan.

.PARAMETER ShareName
    Nama share printer (lihat output script host).

.PARAMETER Repair
    Hapus koneksi lama lalu pasang ulang. Berguna kalau printer
    "hilang" atau driver-nya rusak.

.PARAMETER ApplyCompatFix
    Set RpcAuthnLevelPrivacyEnabled=0 di KLIEN (fix 0x0000011b).
    Butuh Administrator.

.EXAMPLE
    .\02-Connect-Win10.ps1 -Server PC-HOST -ShareName EPSON-L120

.EXAMPLE
    .\02-Connect-Win10.ps1 -Server PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage

.EXAMPLE
    .\02-Connect-Win10.ps1 -Server PC-HOST -ShareName EPSON-L120 -Repair -SaveCredential
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Position = 0)][string]$Server,
    [Parameter(Position = 1)][string]$ShareName,
    [ValidateSet('Auto', 'Modern', 'Legacy')][string]$Mode = 'Auto',
    [switch]$SaveCredential,
    [System.Management.Automation.PSCredential]$Credential,
    [switch]$SetDefault,
    [switch]$TestPage,
    [switch]$Repair,
    [switch]$ApplyCompatFix,
    [switch]$ListRemote
)

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

function Get-WmiPrinter {
    param([string]$Name)
    foreach ($p in @(Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue)) {
        if ($p.Name -eq $Name) { return $p }
    }
    return $null
}

function Show-Hints {
    Write-Host ''
    Write-Host 'Penyebab umum:' -ForegroundColor Yellow
    Write-Host '  0x0000011b  host memblokir RPC lama   -> host: 01 ... -AllowLegacyWin7' -ForegroundColor Gray
    Write-Host '  0x00000bc4  driver tidak ditemukan    -> host: 01 ... -AllowLegacyWin7' -ForegroundColor Gray
    Write-Host '  0x00000709  gagal set default         -> restart Spooler di host dan klien' -ForegroundColor Gray
    Write-Host '  akses ditolak                          -> pakai -SaveCredential' -ForegroundColor Gray
    Write-Host '  port 445 tertutup                      -> host: profil Private + firewall' -ForegroundColor Gray
    Write-Host '  Jika host Windows 7 32-bit, host tidak bisa kirim driver - hubungi admin.' -ForegroundColor DarkGray
    Write-Host ''
}

# Baca OS tanpa memicu pesan "What if: Set Alias" saat modul CimCmdlets
# dimuat pertama kali di bawah -WhatIf.
function Get-HostOsInfo {
    $prev = $WhatIfPreference
    $WhatIfPreference = $false
    try { return Get-CimInstance -ClassName Win32_OperatingSystem }
    finally { $WhatIfPreference = $prev }
}

$os = Get-HostOsInfo
if ([int]$os.BuildNumber -ge 22000) {
    Write-Host 'OS ini Windows 11. File Win10 tetap jalan, tapi lebih tepat:' -ForegroundColor Yellow
    Write-Host '  ..\Win11\02-Connect-Win11.ps1' -ForegroundColor Gray
    Write-Host ''
}

# ----------------------------------------------------------------------------
if ($ListRemote) {
    if (-not $Server) { Write-Host 'Butuh -Server <host>' -ForegroundColor Red; exit 2 }
    Write-Host ('Printer yang di-share di {0}:' -f $Server) -ForegroundColor Cyan
    try {
        $remote = @(Get-WmiObject -Class Win32_Printer -ComputerName $Server -ErrorAction Stop)
    }
    catch {
        Write-Host ('Gagal query WMI: {0}' -f $_.Exception.Message) -ForegroundColor Red
        Write-Host ('Coba manual: net view \\{0}' -f $Server) -ForegroundColor Gray
        exit 3
    }
    $shared = @($remote | Where-Object { $_.Shared -eq $true })
    if ($shared.Count -eq 0) { Write-Host 'Tidak ada printer shared / WMI diblokir.' -ForegroundColor Yellow; exit 0 }
    $shared | Select-Object Name, ShareName, DriverName | Format-Table -AutoSize | Out-String | Write-Host
    exit 0
}

if (-not $Server -or -not $ShareName) {
    Write-Host ''
    Write-Host 'Pemakaian:' -ForegroundColor Yellow
    Write-Host '  .\02-Connect-Win10.ps1 -Server <host> -ShareName <share> [opsi]' -ForegroundColor Gray
    Write-Host '  .\02-Connect-Win10.ps1 -Server <host> -ListRemote' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Opsi: -SetDefault -TestPage -Repair -SaveCredential -ApplyCompatFix' -ForegroundColor Gray
    Write-Host ''
    exit 2
}

$unc = '\\{0}\{1}' -f $Server, $ShareName
Write-Host ''
Write-Host ('Target: {0}' -f $unc) -ForegroundColor Cyan

# ----------------------------------------------------------------------------
if ($ApplyCompatFix) {
    if (-not (Test-IsAdmin)) {
        Write-Host '  [WARN] ApplyCompatFix butuh Administrator - dilewati.' -ForegroundColor Yellow
    }
    elseif ($PSCmdlet.ShouldProcess('Print RPC', 'Set RpcAuthnLevelPrivacyEnabled=0')) {
        & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Control\Print' /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 0 /f | Out-Null
        Restart-Service -Name Spooler -Force
        Write-Host '  [OK] RpcAuthnLevelPrivacyEnabled = 0' -ForegroundColor Green
    }
}

if ($Server -ne '.' -and $Server -ne 'localhost' -and $Server -ne $env:COMPUTERNAME) {
    if (Test-TcpPort -Computer $Server -Port 445) { Write-Host '  [OK] Port 445 terbuka' -ForegroundColor Green }
    else {
        Write-Host '  [FAIL] Port 445 tidak terjangkau' -ForegroundColor Red
        Show-Hints
        exit 3
    }
    if (-not (Test-TcpPort -Computer $Server -Port 135)) {
        Write-Host '  [WARN] Port 135 tertutup - install driver bisa gagal' -ForegroundColor Yellow
    }
}

# ----------------------------------------------------------------------------
if ($Mode -eq 'Auto') {
    if (Get-Command Add-Printer -ErrorAction SilentlyContinue) { $Mode = 'Modern' } else { $Mode = 'Legacy' }
}
Write-Host ('Mode  : {0}' -f $Mode) -ForegroundColor Cyan

$existing = $null
foreach ($p in @(Get-Printer -ErrorAction SilentlyContinue)) { if ($p.Name -eq $unc) { $existing = $p } }

if ($existing -and $Repair) {
    if ($PSCmdlet.ShouldProcess($unc, 'Hapus koneksi lama')) {
        try { Remove-Printer -Name $unc -ErrorAction Stop; Write-Host '  [OK] Koneksi lama dihapus' -ForegroundColor Green }
        catch { Write-Host ('  [WARN] Gagal hapus: {0}' -f $_.Exception.Message) -ForegroundColor Yellow }
    }
    $existing = $null
}

if ($existing) {
    Write-Host ('  [OK] Sudah terpasang: {0}' -f $existing.Name) -ForegroundColor Green
}
elseif ($Mode -eq 'Modern') {
    if ($SaveCredential -and $PSCmdlet.ShouldProcess($Server, 'Simpan kredensial')) {
        if (-not $Credential) { $Credential = Get-Credential -Message "Akun di $Server" }
        if ($Credential) {
            & cmdkey.exe ('/add:' + $Server) ('/user:' + $Credential.UserName) ('/pass:' + $Credential.GetNetworkCredential().Password) | Out-Null
            Write-Host '  [OK] Kredensial disimpan' -ForegroundColor Green
        }
    }
    if ($PSCmdlet.ShouldProcess($unc, 'Add-Printer -ConnectionName')) {
        try {
            Add-Printer -ConnectionName $unc -ErrorAction Stop | Out-Null
            Write-Host ('  [OK] Terpasang: {0}' -f $unc) -ForegroundColor Green
        }
        catch {
            Write-Host ('  [FAIL] {0}' -f $_.Exception.Message) -ForegroundColor Red
            Show-Hints
            exit 4
        }
    }
}
else {
    if ($SaveCredential -and $PSCmdlet.ShouldProcess($Server, 'Simpan kredensial')) {
        if (-not $Credential) { $Credential = Get-Credential -Message "Akun di $Server" }
        if ($Credential) {
            & cmdkey.exe ('/add:' + $Server) ('/user:' + $Credential.UserName) ('/pass:' + $Credential.GetNetworkCredential().Password) | Out-Null
            Write-Host '  [OK] Kredensial disimpan' -ForegroundColor Green
        }
    }
    if ($PSCmdlet.ShouldProcess($unc, 'printui /in')) {
        $argLine = 'printui.dll,PrintUIEntry /in /n "' + $unc + '"'
        $proc = Start-Process -FilePath 'rundll32.exe' -ArgumentList $argLine -Wait -PassThru
        $found = $null
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 1
            foreach ($p in @(Get-Printer -ErrorAction SilentlyContinue)) { if ($p.Name -eq $unc) { $found = $p } }
            if ($found) { break }
        }
        if (-not $found) {
            Write-Host '  [FAIL] Printer tidak muncul setelah 30 detik' -ForegroundColor Red
            Show-Hints
            exit 4
        }
        Write-Host ('  [OK] Terpasang: {0}' -f $unc) -ForegroundColor Green
    }
}

# ----------------------------------------------------------------------------
if ($SetDefault -and -not $WhatIfPreference) {
    $wmi = Get-WmiPrinter -Name $unc
    if ($wmi) { $wmi.SetDefaultPrinter() | Out-Null; Write-Host '  [OK] Printer default diset' -ForegroundColor Green }
    else { Write-Host '  [WARN] Tidak bisa set default' -ForegroundColor Yellow }
}

if ($TestPage -and -not $WhatIfPreference) {
    $wmi = Get-WmiPrinter -Name $unc
    if ($wmi) { $wmi.PrintTestPage() | Out-Null; Write-Host '  [OK] Test page dikirim' -ForegroundColor Green }
    else { Write-Host '  [WARN] Test page gagal' -ForegroundColor Yellow }
}

Write-Host ''
Write-Host 'Selesai.' -ForegroundColor Cyan
Write-Host ''
exit 0
