#Requires -Version 2.0
<#
.SYNOPSIS
    Menu interaktif Printer Sharing Toolkit.

.DESCRIPTION
    Pembungkus ramah pengguna untuk seluruh script toolkit:
    HOST (bagikan printer), KLIEN (sambung), DIAGNOSA, PERBAIKAN, dan ROLLBACK.
    Pengguna cukup memilih nomor - tidak perlu mengetik parameter panjang.

    Jalankan lewat Menu.cmd (otomatis meminta hak Administrator).

    Kompatibel PowerShell 2.0 (Windows 7) sampai 5.1+ (Windows 10/11).

.NOTES
    Script ini HANYA memanggil script asli di folder host\, client\, dan tools\.
    Script asli tidak diubah, jadi tetap bisa dipakai manual seperti sebelumnya.
#>

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Lokasi script (PowerShell 2.0 tidak punya $PSScriptRoot)
# ---------------------------------------------------------------------------
$Script:Root = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Versi aplikasi (dibaca dari file VERSION; tetap kompatibel PS 2.0)
$Script:Version = '1.0.0'
$Script:VersionFile = Join-Path $Script:Root 'VERSION'
if (Test-Path -LiteralPath $Script:VersionFile) {
    try {
        $firstLine = Get-Content -LiteralPath $Script:VersionFile | Select-Object -First 1
        if ($firstLine) { $Script:Version = ([string]$firstLine).Trim() }
    }
    catch { }
}

# ---------------------------------------------------------------------------
# Deteksi OS & arsitektur
# ---------------------------------------------------------------------------
function Get-OsFamily {
    $major = 6; $minor = 1; $build = 7601
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        $parts = ([string]$os.Version).Split('.')
        if ($parts.Length -ge 2) {
            $major = [int]$parts[0]
            $minor = [int]$parts[1]
        }
        if ($os.BuildNumber) { $build = [int]$os.BuildNumber }
    }
    catch {
        $v = [System.Environment]::OSVersion.Version
        $major = $v.Major; $minor = $v.Minor; $build = $v.Build
    }

    if ($major -eq 6 -and $minor -eq 1) { return 'Win7' }
    if ($major -eq 6 -and ($minor -eq 2 -or $minor -eq 3)) { return 'Win8' }
    if ($major -ge 10 -and $build -ge 22000) { return 'Win11' }
    return 'Win10'
}

$Script:OsFamily = Get-OsFamily

$Script:ArchBits = '64-bit'
if ($env:PROCESSOR_ARCHITECTURE -eq 'x86' -and -not $env:PROCESSOR_ARCHITEW6432) {
    $Script:ArchBits = '32-bit'
}

function Get-OsLabel {
    switch ($Script:OsFamily) {
        'Win7'  { return 'Windows 7' }
        'Win8'  { return 'Windows 8/8.1 (belum resmi didukung)' }
        'Win11' { return 'Windows 11' }
        default { return 'Windows 10' }
    }
}

function Get-HostScript {
    switch ($Script:OsFamily) {
        'Win7'  { return (Join-Path $Script:Root 'host\Win7\01-Sharing-Win7.ps1') }
        'Win11' { return (Join-Path $Script:Root 'host\Win11\01-Sharing-Win11.ps1') }
        default { return (Join-Path $Script:Root 'host\Win10\01-Sharing-Win10.ps1') }
    }
}

function Get-ClientScript {
    switch ($Script:OsFamily) {
        'Win7'  { return (Join-Path $Script:Root 'client\Win7\02-Connect-Win7.ps1') }
        'Win11' { return (Join-Path $Script:Root 'client\Win11\02-Connect-Win11.ps1') }
        default { return (Join-Path $Script:Root 'client\Win10\02-Connect-Win10.ps1') }
    }
}

# ---------------------------------------------------------------------------
# Tampilan & input
# ---------------------------------------------------------------------------
function Write-Header {
    param([string]$Text)
    Write-Host ''
    Write-Host ('============================================================') -ForegroundColor Cyan
    Write-Host ('  ' + $Text) -ForegroundColor Cyan
    Write-Host ('============================================================') -ForegroundColor Cyan
    Write-Host ''
}

function Pause-Menu {
    Write-Host ''
    [void](Read-Host '  Tekan Enter untuk kembali ke menu')
}

function Read-YesNo {
    param([string]$Prompt, [bool]$Default = $false)
    $hint = ' [y/N]'
    if ($Default) { $hint = ' [Y/n]' }
    while ($true) {
        $a = Read-Host ($Prompt + $hint)
        if ($null -eq $a) { return $Default }
        $a = $a.Trim()
        if ($a -eq '') { return $Default }
        if ($a -match '^(y|ya|yes)$') { return $true }
        if ($a -match '^(n|no|tidak)$') { return $false }
        Write-Host '  Jawab y atau n.' -ForegroundColor Yellow
    }
}

function Read-Text {
    param([string]$Prompt, [string]$Default = '')
    $p = $Prompt
    if ($Default -ne '') { $p = $Prompt + ' [' + $Default + ']' }
    $a = Read-Host $p
    if ($null -eq $a) { $a = '' }
    $a = $a.Trim()
    if ($a -eq '' -and $Default -ne '') { return $Default }
    return $a
}

# ---------------------------------------------------------------------------
# Pemanggil script asli (in-process; exit di script anak tidak menutup menu)
# ---------------------------------------------------------------------------
function Format-ToolArgs {
    param($ToolArgs)
    if ($null -eq $ToolArgs) { return '' }
    if ($ToolArgs -is [hashtable]) {
        $parts = @()
        foreach ($k in $ToolArgs.Keys) {
            $v = $ToolArgs[$k]
            if ($v -is [bool]) { if ($v) { $parts += ('-' + $k) } }
            else { $parts += ('-' + $k + ' "' + $v + '"') }
        }
        return ($parts -join ' ')
    }
    $parts = @()
    foreach ($item in $ToolArgs) { $parts += [string]$item }
    return ($parts -join ' ')
}

function Invoke-Tool {
    param([string]$Path, $ToolArgs)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host ''
        Write-Host ('  [ERROR] Script tidak ditemukan: ' + $Path) -ForegroundColor Red
        Pause-Menu
        return
    }

    $shown = Split-Path -Leaf $Path
    $argText = Format-ToolArgs $ToolArgs
    if ($argText -ne '') { $shown = $shown + ' ' + $argText }
    Write-Host ''
    Write-Host ('  > ' + $shown) -ForegroundColor DarkGray
    Write-Host ''

    try {
        if ($ToolArgs -is [hashtable]) { & $Path @ToolArgs }
        elseif ($ToolArgs -and $ToolArgs.Count -gt 0) { & $Path @ToolArgs }
        else { & $Path }
    }
    catch {
        Write-Host ('  [ERROR] ' + $_.Exception.Message) -ForegroundColor Red
    }
    finally {
        # Pastikan transcript script host tidak "bocor" ke menu.
        try { Stop-Transcript | Out-Null } catch { }
    }

    Pause-Menu
}

# ---------------------------------------------------------------------------
# Pemilih printer lokal
# ---------------------------------------------------------------------------
function Get-LocalPrinterNames {
    $names = @()
    if (Get-Command Get-Printer -ErrorAction SilentlyContinue) {
        $names = @(Get-Printer -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    }
    if ($names.Count -eq 0) {
        $names = @(Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue |
                   Select-Object -ExpandProperty Name)
    }
    return $names
}

function Select-PrinterName {
    $names = @(Get-LocalPrinterNames)
    Write-Host ''
    if ($names.Count -eq 0) {
        Write-Host '  Tidak ada printer terdeteksi di PC ini.' -ForegroundColor Yellow
        return $null
    }
    Write-Host '  Printer yang terdeteksi:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $names.Count; $i++) {
        Write-Host ('    ' + ($i + 1) + '. ' + $names[$i])
    }
    Write-Host ''
    $a = Read-Host '  Pilih nomor, atau ketik nama printer persis (Enter = batal)'
    if ($null -eq $a) { return $null }
    $a = $a.Trim()
    if ($a -eq '') { return $null }
    if ($a -match '^[0-9]+$') {
        $idx = [int]$a - 1
        if ($idx -ge 0 -and $idx -lt $names.Count) { return $names[$idx] }
        Write-Host '  Nomor di luar rentang.' -ForegroundColor Yellow
        return $null
    }
    return $a
}

# ---------------------------------------------------------------------------
# Menu utama
# ---------------------------------------------------------------------------
function Show-MainMenu {
    Clear-Host
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ('                 PRINTER SHARING TOOLKIT  v' + $Script:Version) -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ('  OS ini : ' + (Get-OsLabel) + ' ' + $Script:ArchBits) -ForegroundColor Gray
    Write-Host ''
    Write-Host '   1. HOST      - Bagikan printer dari PC ini'
    Write-Host '   2. KLIEN     - Sambungkan ke printer yang dibagikan'
    Write-Host '   3. DIAGNOSA  - Cek masalah sharing (read-only)'
    Write-Host '   4. PERBAIKAN - Fix kompatibilitas Windows 7'
    Write-Host '   5. ROLLBACK  - Kembalikan pengaturan host'
    Write-Host '   0. Keluar'
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Menu HOST
# ---------------------------------------------------------------------------
function Start-HostSharing {
    param([bool]$DryRun = $false)

    Clear-Host
    Write-Header 'HOST - Bagikan printer dari PC ini'
    if ($DryRun) {
        Write-Host '  Mode SIMULASI (dry-run): tidak ada perubahan yang diterapkan.' -ForegroundColor Yellow
        Write-Host ''
    }

    $printer = Select-PrinterName
    if (-not $printer) { Write-Host '  Dibatalkan.' -ForegroundColor Yellow; Pause-Menu; return }

    $share = Read-Text '  Nama share (opsional, Enter = otomatis dari nama printer)'

    $toolArgs = @{ PrinterName = $printer }
    if ($share -ne '') { $toolArgs['ShareName'] = $share }

    if ($Script:OsFamily -eq 'Win7') {
        if (Read-YesNo '  Aktifkan SMB2 bila dimatikan?' $false) { $toolArgs['EnableSMB2'] = $true }
    }
    else {
        $legacy = Read-YesNo '  Ada klien Windows 7 di jaringan? (menurunkan keamanan)' $false
        if ($legacy) {
            $toolArgs['AllowLegacyWin7'] = $true
            if (Read-YesNo '    Izinkan akses tanpa password (guest)?' $false) { $toolArgs['AllowGuest'] = $true }
            if (Read-YesNo '    Aktifkan NetBIOS (memudahkan Win7 menemukan PC)?' $false) { $toolArgs['EnableNetBios'] = $true }
        }
        if (Read-YesNo '  Izinkan semua orang mencetak (Everyone: Print)?' $false) { $toolArgs['GrantEveryonePrint'] = $true }
    }

    if ($DryRun) {
        $toolArgs['WhatIf'] = $true
    }
    elseif (-not (Read-YesNo '  Terapkan sekarang?' $true)) {
        Write-Host '  Dibatalkan.' -ForegroundColor Yellow
        Pause-Menu
        return
    }

    Invoke-Tool (Get-HostScript) $toolArgs
}

function Show-HostMenu {
    while ($true) {
        Clear-Host
        Write-Header 'HOST - Bagikan printer'
        Write-Host ('  Script host otomatis dipilih untuk: ' + (Get-OsLabel))
        Write-Host ''
        Write-Host '   1. Tampilkan daftar printer di PC ini'
        Write-Host '   2. Bagikan printer (langkah demi langkah)'
        Write-Host '   3. Simulasi dulu (dry-run, tidak mengubah apa pun)'
        Write-Host '   0. Kembali'
        Write-Host ''
        $c = Read-Host '  Pilih'
        if ($null -eq $c) { return }
        switch ($c.Trim()) {
            '1' { Invoke-Tool (Get-HostScript) @{ ListPrinters = $true } }
            '2' { Start-HostSharing $false }
            '3' { Start-HostSharing $true }
            '0' { return }
            default { Write-Host '  Pilihan tidak dikenal.' -ForegroundColor Yellow }
        }
    }
}

# ---------------------------------------------------------------------------
# Menu KLIEN
# ---------------------------------------------------------------------------
function Start-Win7Batch {
    Clear-Host
    Write-Header 'KLIEN Win7 - Sambung cepat (batch)'
    Write-Host '  Cara ini untuk Windows 7 64-bit. Untuk 32-bit pakai mode LocalPort.' -ForegroundColor Gray
    Write-Host ''

    $server = Read-Text '  Nama/IP komputer host (tanpa \\ )'
    if ($server -eq '') { Write-Host '  Host wajib diisi.' -ForegroundColor Yellow; Pause-Menu; return }

    $share = Read-Text '  Nama share printer (lihat output script host)'
    if ($share -eq '') { Write-Host '  Nama share wajib diisi.' -ForegroundColor Yellow; Pause-Menu; return }

    $testStr = '-'
    if (Read-YesNo '  Cetak halaman uji?' $false) { $testStr = 'test' }
    $repairStr = '-'
    if (Read-YesNo '  Hapus koneksi lama dulu (repair)?' $false) { $repairStr = 'repair' }

    $cmdPath = Join-Path $Script:Root 'client\Win7\02-Connect-Win7.cmd'
    Invoke-Tool $cmdPath @($server, $share, '-', '-', $testStr, $repairStr)
}

function Start-ClientConnect {
    param([string]$Action, [switch]$LocalPort)

    Clear-Host
    Write-Header 'KLIEN - Sambungkan ke printer host'
    $scriptPath = Get-ClientScript

    $server = Read-Text '  Nama/IP komputer host (tanpa \\ )'
    if ($server -eq '') { Write-Host '  Host wajib diisi.' -ForegroundColor Yellow; Pause-Menu; return }

    if ($Action -eq 'list') {
        Invoke-Tool $scriptPath @{ Server = $server; ListRemote = $true }
        return
    }

    $share = Read-Text '  Nama share printer (lihat output script host)'
    if ($share -eq '') { Write-Host '  Nama share wajib diisi.' -ForegroundColor Yellow; Pause-Menu; return }

    $toolArgs = @{ Server = $server; ShareName = $share }
    if ($Action -eq 'repair') { $toolArgs['Repair'] = $true }

    if ($LocalPort) {
        $inf = Read-Text '  Path file driver 32-bit (.inf)'
        if ($inf -eq '') { Write-Host '  DriverInf wajib untuk mode LocalPort.' -ForegroundColor Yellow; Pause-Menu; return }
        $toolArgs['Mode'] = 'LocalPort'
        $toolArgs['DriverInf'] = $inf
    }
    else {
        if (Read-YesNo '  Jadikan printer default?' $true) { $toolArgs['SetDefault'] = $true }
        if (Read-YesNo '  Cetak halaman uji setelah tersambung?' $false) { $toolArgs['TestPage'] = $true }
        if (Read-YesNo '  Simpan kredensial (bila host minta login)?' $false) { $toolArgs['SaveCredential'] = $true }
        if ($Script:OsFamily -ne 'Win7') {
            if (Read-YesNo '  Terapkan fix kompatibilitas RPC (error 0x0000011b)?' $false) { $toolArgs['ApplyCompatFix'] = $true }
        }
    }

    Invoke-Tool $scriptPath $toolArgs
}

function Show-ClientMenu {
    while ($true) {
        Clear-Host
        Write-Header 'KLIEN - Sambungkan ke printer yang dibagikan'
        Write-Host ('  OS klien ini: ' + (Get-OsLabel) + ' ' + $Script:ArchBits)
        Write-Host ''
        Write-Host '   1. Lihat printer yang dibagikan di host'
        Write-Host '   2. Sambungkan ke printer host'
        Write-Host '   3. Sambungkan ulang / perbaiki (Repair)'
        if ($Script:OsFamily -eq 'Win7') {
            Write-Host '   4. Sambung cepat via batch (khusus Win7 64-bit)'
            Write-Host '   5. Mode LocalPort + driver 32-bit (khusus Win7 32-bit)'
        }
        Write-Host '   0. Kembali'
        Write-Host ''
        $c = Read-Host '  Pilih'
        if ($null -eq $c) { return }
        switch ($c.Trim()) {
            '1' { Start-ClientConnect -Action 'list' }
            '2' { Start-ClientConnect -Action 'connect' }
            '3' { Start-ClientConnect -Action 'repair' }
            '4' {
                if ($Script:OsFamily -eq 'Win7') { Start-Win7Batch }
                else { Write-Host '  Pilihan hanya untuk Windows 7.' -ForegroundColor Yellow }
            }
            '5' {
                if ($Script:OsFamily -eq 'Win7') { Start-ClientConnect -Action 'connect' -LocalPort }
                else { Write-Host '  Pilihan hanya untuk Windows 7.' -ForegroundColor Yellow }
            }
            '0' { return }
            default { Write-Host '  Pilihan tidak dikenal.' -ForegroundColor Yellow }
        }
    }
}

# ---------------------------------------------------------------------------
# Menu DIAGNOSA
# ---------------------------------------------------------------------------
function Show-DiagMenu {
    Clear-Host
    Write-Header 'DIAGNOSA - Cek masalah sharing (read-only)'
    Write-Host '  Kosongkan nama host bila ingin memeriksa PC ini sendiri.' -ForegroundColor Gray
    Write-Host '  Jalankan di HOST dan di KLIEN untuk membandingkan hasil.' -ForegroundColor Gray
    Write-Host ''

    $server = Read-Text '  Nama/IP host (Enter = PC ini)'
    $share = Read-Text '  Nama share printer (opsional)'
    $printer = Read-Text '  Nama printer lokal untuk cek driver (opsional)'

    $toolArgs = @{}
    if ($server -ne '') { $toolArgs['Server'] = $server }
    if ($share -ne '') { $toolArgs['ShareName'] = $share }
    if ($printer -ne '') { $toolArgs['PrinterName'] = $printer }

    Invoke-Tool (Join-Path $Script:Root 'tools\03-Test-PrinterShare.ps1') $toolArgs
}

# ---------------------------------------------------------------------------
# Menu PERBAIKAN
# ---------------------------------------------------------------------------
function Show-FixMenu {
    Clear-Host
    Write-Header 'PERBAIKAN - Kompatibilitas Windows 7'
    Write-Host '  Menyetel ulang RpcAuthnLevelPrivacyEnabled dan kebijakan Point and Print'
    Write-Host '  pada PC ini (biasanya di HOST) untuk mengatasi error 0x0000011b'
    Write-Host '  dan 0x00000bc4 dari klien lama.' -ForegroundColor Gray
    Write-Host ''

    if (-not (Read-YesNo '  Aktifkan mode kompatibel Windows 7 (menurunkan keamanan)?' $true)) {
        Write-Host '  Tidak ada perubahan.' -ForegroundColor Yellow
        Pause-Menu
        return
    }

    $toolArgs = @{ AllowLegacyWin7 = $true }
    if (Read-YesNo '  Sekaligus izinkan akses tanpa password (guest)?' $false) { $toolArgs['AllowGuest'] = $true }

    Invoke-Tool (Join-Path $Script:Root 'tools\04-Fix-LegacyCompat.ps1') $toolArgs
}

# ---------------------------------------------------------------------------
# Menu ROLLBACK
# ---------------------------------------------------------------------------
function Show-RollbackMenu {
    Clear-Host
    Write-Header 'ROLLBACK - Kembalikan pengaturan host'

    if ($Script:OsFamily -eq 'Win7') {
        $scriptPath = Join-Path $Script:Root 'tools\05-Rollback-Win7.ps1'
        $fileParam = 'JournalFile'
        Write-Host '  Script: 05-Rollback-Win7.ps1' -ForegroundColor Gray
    }
    else {
        $scriptPath = Join-Path $Script:Root 'tools\05-Rollback.ps1'
        $fileParam = 'BackupFile'
        Write-Host '  Script: 05-Rollback.ps1' -ForegroundColor Gray
    }
    Write-Host '  Kosongkan path file untuk memakai cadangan terbaru.' -ForegroundColor Gray
    Write-Host ''

    $file = Read-Text '  Path file backup/journal (opsional)'

    if (-not (Read-YesNo '  Lanjutkan rollback?' $false)) {
        Write-Host '  Dibatalkan.' -ForegroundColor Yellow
        Pause-Menu
        return
    }

    $toolArgs = @{}
    if ($file -ne '') { $toolArgs[$fileParam] = $file }

    Invoke-Tool $scriptPath $toolArgs
}

# ---------------------------------------------------------------------------
# Loop utama
# ---------------------------------------------------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-Menu {
    if (-not (Test-IsAdmin)) {
        Write-Host ''
        Write-Host '  PERHATIAN: menu ini belum berjalan sebagai Administrator.' -ForegroundColor Yellow
        Write-Host '  Sebaiknya tutup lalu jalankan lewat Menu.cmd.' -ForegroundColor Yellow
        [void](Read-Host '  Tekan Enter untuk lanjut apa adanya')
    }

    while ($true) {
        Show-MainMenu
        $c = Read-Host '  Pilih menu'
        if ($null -eq $c) { return }
        switch ($c.Trim()) {
            '1' { Show-HostMenu }
            '2' { Show-ClientMenu }
            '3' { Show-DiagMenu }
            '4' { Show-FixMenu }
            '5' { Show-RollbackMenu }
            '0' { return }
            default { Write-Host '  Pilihan tidak dikenal.' -ForegroundColor Yellow }
        }
    }
}

Start-Menu
exit 0
