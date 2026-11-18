#Requires -Version 2.0
<#
.SYNOPSIS
    KLIEN Windows 7 - connect ke printer yang di-share PC lain.

.DESCRIPTION
    Dijalankan di PC Windows 7. Kompatibel PowerShell 2.0.

    Mode dipilih otomatis:
      Legacy    : Windows 7 64-bit -> printui /in (Point and Print)
      LocalPort : Windows 7 32-bit -> printer lokal + port \\HOST\Share
                  (host x64 TIDAK bisa mengirim driver x86 - ini penyebab
                   error 0x0000007e yang paling sering)

    Untuk Windows 10 pakai ..\Win10\02-Connect-Win10.ps1
    Untuk Windows 11 pakai ..\Win11\02-Connect-Win11.ps1

.PARAMETER DriverInf
    Wajib untuk -Mode LocalPort. File .inf driver 32-bit (x86) dari vendor.

.PARAMETER DriverName
    Opsional. Nama model di dalam INF. Kosongkan agar Windows menampilkan
    daftar pilihan driver.

.EXAMPLE
    .\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120

.EXAMPLE
    .\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage

.EXAMPLE
    .\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120 -Mode LocalPort -DriverInf "C:\Driver\x86\driver.inf"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Server,
    [Parameter(Position = 1)][string]$ShareName,
    [ValidateSet('Auto', 'Legacy', 'LocalPort')][string]$Mode = 'Auto',
    [string]$DriverInf,
    [string]$DriverName,
    [string]$PrinterLabel,
    [switch]$SaveCredential,
    [System.Management.Automation.PSCredential]$Credential,
    [switch]$SetDefault,
    [switch]$TestPage,
    [switch]$Repair,
    [switch]$ListRemote,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Write-Ok    { param([string]$T) Write-Host ('  [OK]   ' + $T) -ForegroundColor Green }
function Write-Warn2 { param([string]$T) Write-Host ('  [WARN] ' + $T) -ForegroundColor Yellow }
function Write-Fail2 { param([string]$T) Write-Host ('  [FAIL] ' + $T) -ForegroundColor Red }
function Write-Info2 { param([string]$T) Write-Host ('  [INFO] ' + $T) -ForegroundColor Cyan }

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

function Get-PrinterList { return @(Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue) }

function Find-Printer {
    param([string]$Name)
    foreach ($p in (Get-PrinterList)) { if ($p.Name -eq $Name) { return $p } }
    return $null
}

# Menyimpan kredensial ke Windows Credential Manager TANPA menaruh password di
# command line. Cara lama (cmdkey /pass:...) membuat password terlihat di daftar
# proses. Di sini dipakai CredWriteW dari advapi32.dll - cara yang sama yang
# dipakai cmdkey secara internal - dengan password dikirim lewat memori.
$script:CredentialApiSource = @'
using System;
using System.Runtime.InteropServices;

public static class PrinterShareCredential {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public int Flags;
        public int Type;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetAlias;
        [MarshalAs(UnmanagedType.LPWStr)] public string UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredWrite(ref CREDENTIAL userCredential, int flags);
}
'@

function Save-HostCredential {
    param([string]$Computer, [System.Management.Automation.PSCredential]$Credential)

    if (-not ('PrinterShareCredential' -as [type])) {
        Add-Type -TypeDefinition $script:CredentialApiSource -ErrorAction Stop
    }

    $bytes = [System.Text.Encoding]::Unicode.GetBytes($Credential.GetNetworkCredential().Password)
    $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($bytes.Length)
    try {
        [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $ptr, $bytes.Length)

        $cred = New-Object 'PrinterShareCredential+CREDENTIAL'
        $cred.Type = 2                      # CRED_TYPE_DOMAIN_PASSWORD
        $cred.TargetName = 'Domain:target=' + $Computer
        $cred.CredentialBlob = $ptr
        $cred.CredentialBlobSize = $bytes.Length
        $cred.Persist = 2                   # CRED_PERSIST_LOCAL_MACHINE
        $cred.UserName = $Credential.UserName

        if ([PrinterShareCredential]::CredWrite([ref]$cred, 0)) { return 0 }
        return [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr)
    }
}

function Show-Hints {
    Write-Host ''
    Write-Host 'Penyebab umum:' -ForegroundColor Yellow
    Write-Host '  0x0000011b  host memblokir RPC lama -> di HOST jalankan 01 dengan -AllowLegacyWin7' -ForegroundColor Gray
    Write-Host '  0x00000bc4  driver tidak ada        -> sama, atau pakai -Mode LocalPort' -ForegroundColor Gray
    Write-Host '  0x0000007e  beda arsitektur        -> -Mode LocalPort + driver x86' -ForegroundColor Gray
    Write-Host '  akses ditolak                       -> pakai -SaveCredential' -ForegroundColor Gray
    Write-Host ''
}

$osArch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $osArch = $env:PROCESSOR_ARCHITEW6432 }
$is64 = ($osArch -ne 'x86')

Write-Host ''
Write-Info2 ('Klien: Windows 7 ({0})  PowerShell {1}' -f $osArch, $PSVersionTable.PSVersion)

# ----------------------------------------------------------------------------
if ($ListRemote) {
    if (-not $Server) { Write-Fail2 'Butuh -Server <host>'; exit 2 }
    Write-Info2 ('Printer di {0}:' -f $Server)
    try { $remote = @(Get-WmiObject -Class Win32_Printer -ComputerName $Server -ErrorAction Stop) }
    catch { Write-Fail2 ('WMI gagal: {0}' -f $_.Exception.Message); exit 3 }
    $shared = @($remote | Where-Object { $_.Shared -eq $true })
    if ($shared.Count -eq 0) { Write-Warn2 'Tidak ada printer shared / WMI diblokir'; exit 0 }
    $shared | Select-Object Name, ShareName, DriverName | Format-Table -AutoSize | Out-String | Write-Host
    exit 0
}

if (-not $Server -or -not $ShareName) {
    Write-Host ''
    Write-Host 'Pemakaian:' -ForegroundColor Yellow
    Write-Host '  .\02-Connect-Win7.ps1 -Server <host> -ShareName <share> [opsi]' -ForegroundColor Gray
    Write-Host '  .\02-Connect-Win7.ps1 -Server <host> -ListRemote' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Opsi: -SetDefault -TestPage -Repair -SaveCredential -WhatIf' -ForegroundColor Gray
    Write-Host '      -Mode LocalPort -DriverInf <inf> -DriverName <nama> -PrinterLabel <nama>' -ForegroundColor Gray
    Write-Host ''
    exit 2
}

$unc = '\\{0}\{1}' -f $Server, $ShareName
Write-Info2 ('Target: {0}' -f $unc)

# ----------------------------------------------------------------------------
if ($Mode -eq 'Auto') {
    if ($is64) { $Mode = 'Legacy' } else { $Mode = 'LocalPort' }
}

if ($Mode -eq 'LocalPort' -and -not $DriverInf) {
    Write-Host ''
    Write-Fail2 'Mode LocalPort butuh -DriverInf (driver 32-bit / x86).'
    Write-Host ''
    Write-Host 'Langkah:' -ForegroundColor Yellow
    Write-Host '  1. Download driver dari situs vendor, pilih versi 32-bit.' -ForegroundColor Gray
    Write-Host '  2. Extract ke C:\Driver\x86\' -ForegroundColor Gray
    Write-Host '  3. Cari file .inf, lalu jalankan:' -ForegroundColor Gray
    Write-Host ('     .\02-Connect-Win7.ps1 -Server {0} -ShareName {1} -Mode LocalPort -DriverInf "C:\Driver\x86\nama.inf"' -f $Server, $ShareName) -ForegroundColor Gray
    Write-Host ''
    exit 2
}

Write-Info2 ('Mode : {0}' -f $Mode)

if (-not (Test-IsAdmin)) { Write-Warn2 'Bukan Administrator - instalasi driver bisa meminta UAC' }

# ----------------------------------------------------------------------------
if ($Server -ne '.' -and $Server -ne 'localhost' -and $Server -ne $env:COMPUTERNAME) {
    if (Test-TcpPort -Computer $Server -Port 445) { Write-Ok 'Port 445 terbuka' }
    else {
        Write-Fail2 'Port 445 tidak terjangkau'
        Write-Warn2 'Periksa: host hidup, firewall host, profil host Private'
        exit 3
    }
    if (-not (Test-TcpPort -Computer $Server -Port 135)) { Write-Warn2 'Port 135 tertutup - install driver bisa gagal' }
}

if ($SaveCredential) {
    if (-not $Credential) { $Credential = Get-Credential -Credential $null }
    if ($Credential -and -not $WhatIf) {
        $rc = Save-HostCredential -Computer $Server -Credential $Credential
        if ($rc -eq 0) { Write-Ok 'Kredensial disimpan (Credential Manager)' }
        else { Write-Warn2 ('Gagal menyimpan kredensial (kode {0})' -f $rc) }
    }
}

# ----------------------------------------------------------------------------
if ($Mode -eq 'Legacy') {
    $existing = Find-Printer -Name $unc

    if ($existing -and $Repair -and -not $WhatIf) {
        Start-Process -FilePath 'rundll32.exe' -ArgumentList ('printui.dll,PrintUIEntry /dn /n "' + $unc + '"') -Wait
        Start-Sleep -Seconds 2
        $existing = $null
        Write-Ok 'Koneksi lama dihapus'
    }

    if ($existing) { Write-Ok ('Sudah terpasang: ' + $existing.Name) }
    elseif ($WhatIf) { Write-Warn2 ('WhatIf: printui /in /n "' + $unc + '"') }
    else {
        Write-Host '        Menjalankan printui /in (dialog driver mungkin muncul)...' -ForegroundColor DarkGray
        Start-Process -FilePath 'rundll32.exe' -ArgumentList ('printui.dll,PrintUIEntry /in /n "' + $unc + '"') -Wait

        $found = $null
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 1
            $found = Find-Printer -Name $unc
            if ($found) { break }
        }
        if (-not $found) {
            Write-Fail2 'Printer tidak muncul setelah 30 detik'
            Show-Hints
            exit 4
        }
        Write-Ok ('Terpasang: ' + $unc)
    }

    if ($SetDefault -and -not $WhatIf) {
        $wmi = Find-Printer -Name $unc
        if ($wmi) { $wmi.SetDefaultPrinter() | Out-Null; Write-Ok 'Printer default diset' }
        else { Write-Warn2 'Tidak bisa set default' }
    }
    if ($TestPage -and -not $WhatIf) {
        $wmi = Find-Printer -Name $unc
        if ($wmi) { $wmi.PrintTestPage() | Out-Null; Write-Ok 'Test page dikirim' }
        else { Write-Warn2 'Test page gagal' }
    }

    Write-Host ''
    exit 0
}

# ----------------------------------------------------------------------------
# LocalPort
$infResolved = $null
try { $infResolved = (Resolve-Path -LiteralPath $DriverInf -ErrorAction Stop).ProviderPath } catch { }
if (-not $infResolved) {
    Write-Fail2 ('File INF tidak ditemukan: {0}' -f $DriverInf)
    exit 2
}
if (-not $PrinterLabel) { $PrinterLabel = $ShareName }

$existing = Find-Printer -Name $PrinterLabel
if ($existing) { Write-Ok ('Printer lokal sudah ada: ' + $existing.Name) }
elseif ($WhatIf) {
    Write-Warn2 ('WhatIf: printui /if /b "' + $PrinterLabel + '" /f "' + $infResolved + '" /r "' + $unc + '"')
}
else {
    $arg = 'printui.dll,PrintUIEntry /if /b "' + $PrinterLabel + '" /f "' + $infResolved + '" /r "' + $unc + '"'
    if ($DriverName) { $arg = $arg + ' /m "' + $DriverName + '"' }

    Write-Host '        Membuat Local Port + install driver...' -ForegroundColor DarkGray
    Start-Process -FilePath 'rundll32.exe' -ArgumentList $arg -Wait

    $found = $null
    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Seconds 1
        $found = Find-Printer -Name $PrinterLabel
        if ($found) { break }
    }
    if (-not $found) {
        Write-Fail2 'Printer lokal tidak terbentuk'
        Write-Warn2 'Coba ulangi tanpa -DriverName agar daftar driver INF muncul'
        Show-Hints
        exit 4
    }
    Write-Ok ('Dibuat: ' + $PrinterLabel + '  ->  ' + $unc)
}

if ($SetDefault -and -not $WhatIf) {
    $wmi = Find-Printer -Name $PrinterLabel
    if ($wmi) { $wmi.SetDefaultPrinter() | Out-Null; Write-Ok 'Printer default diset' }
    else { Write-Warn2 'Tidak bisa set default' }
}
if ($TestPage -and -not $WhatIf) {
    $wmi = Find-Printer -Name $PrinterLabel
    if ($wmi) { $wmi.PrintTestPage() | Out-Null; Write-Ok 'Test page dikirim' }
    else { Write-Warn2 'Test page gagal' }
}

Write-Host ''
exit 0
