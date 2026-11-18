#Requires -Version 2.0
<#
.SYNOPSIS
    Menu interaktif Printer Sharing Toolkit (dwibahasa ID/EN).

.DESCRIPTION
    Pembungkus ramah pengguna untuk seluruh script toolkit:
    HOST (bagikan), KLIEN (sambung), DIAGNOSA, PERBAIKAN, ROLLBACK,
    LOG, BANTUAN, dan ganti BAHASA.

    Jalankan lewat Menu.cmd (otomatis meminta hak Administrator).

    Kompatibel PowerShell 2.0 (Windows 7) sampai 5.1+ (Windows 10/11).

.NOTES
    Script ini HANYA memanggil script asli di folder host\, client\, dan tools\.
    Script asli tidak diubah, jadi tetap bisa dipakai manual seperti sebelumnya.

    Saat di-dot-source (untuk pengujian), menu tidak dijalankan; hanya
    fungsi dan variabelnya yang dimuat.
#>

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Lokasi script (PowerShell 2.0 tidak punya variabel otomatis PSScriptRoot)
# ---------------------------------------------------------------------------
$Script:Root = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Versi aplikasi (dibaca dari file VERSION)
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
# Bahasa (ID / EN)
# ---------------------------------------------------------------------------
$Script:Lang = 'id'
$Script:LangFile = Join-Path $env:ProgramData 'PrinterShare\lang.txt'

$Script:Strings = @{
    id = @{
        title          = 'PRINTER SHARING TOOLKIT'
        osLine         = 'OS ini'
        shareStatus    = 'Printer dibagikan'
        statusNone     = 'belum ada'
        itemHost       = 'HOST      - Bagikan printer dari PC ini'
        itemClient     = 'KLIEN     - Sambungkan ke printer yang dibagikan'
        itemDiag       = 'DIAGNOSA  - Cek masalah sharing (read-only)'
        itemFix        = 'PERBAIKAN - Fix kompatibilitas Windows 7'
        itemRollback   = 'ROLLBACK  - Kembalikan pengaturan host'
        itemLogs       = 'LOG       - Lihat log & backup terakhir'
        itemHelp       = 'BANTUAN   - Panduan singkat & buka README'
        itemLang       = 'BAHASA    - Ganti bahasa (ID/EN)'
        itemExit       = 'KELUAR'
        choose         = 'Pilih'
        unknownChoice  = 'Pilihan tidak dikenal.'
        cancelled      = 'Dibatalkan.'
        pressEnter     = 'Tekan Enter untuk kembali ke menu'
        invalidYesNo   = 'Jawab y atau n.'
        back           = 'Kembali'

        adminWarn1     = 'PERHATIAN: menu ini belum berjalan sebagai Administrator.'
        adminWarn2     = 'Sebaiknya tutup lalu jalankan lewat Menu.cmd.'
        adminWarn3     = 'Tekan Enter untuk lanjut apa adanya'

        osWin7         = 'Windows 7'
        osWin8         = 'Windows 8/8.1 (belum resmi didukung)'
        osWin10        = 'Windows 10'
        osWin11        = 'Windows 11'

        labelPickPrinter = 'Pilih nomor, atau ketik nama printer persis (Enter = batal)'
        noPrinters       = 'Tidak ada printer terdeteksi di PC ini.'
        detectedPrinters = 'Printer yang terdeteksi:'
        outOfRange       = 'Nomor di luar rentang.'
        required         = '{0} wajib diisi.'
        qHost            = 'Nama/IP komputer host (tanpa \\ )'
        qShare           = 'Nama share printer (lihat output script host)'

        hostHeader     = 'HOST - Bagikan printer dari PC ini'
        hostScriptNote = 'Script host otomatis dipilih untuk: {0}'
        hostItemList   = 'Tampilkan daftar printer di PC ini'
        hostItemShare  = 'Bagikan printer (langkah demi langkah)'
        hostItemDry    = 'Simulasi dulu (dry-run, tidak mengubah apa pun)'
        hostItemUnshare = 'Berhenti membagikan printer (unshare)'
        dryRunNote     = 'Mode SIMULASI (dry-run): tidak ada perubahan yang diterapkan.'
        qShareName     = 'Nama share (opsional, Enter = otomatis dari nama printer)'
        qSmb2          = 'Aktifkan SMB2 bila dimatikan?'
        qLegacy        = 'Ada klien Windows 7 di jaringan? (menurunkan keamanan)'
        qGuest         = 'Izinkan akses tanpa password (guest)?'
        qNetbios       = 'Aktifkan NetBIOS (memudahkan Win7 menemukan PC)?'
        qEveryone      = 'Izinkan semua orang mencetak (Everyone: Print)?'
        qApply         = 'Terapkan sekarang?'
        hostNotShared  = 'Tidak ada printer yang sedang dibagikan.'
        sharedPrinters = 'Printer yang sedang dibagikan:'
        qUnshare       = 'Berhenti membagikan printer ini?'
        unshareDone    = 'Berhasil berhenti membagikan printer.'
        unshareFail    = 'Gagal berhenti membagikan printer (kode {0}).'

        clientHeader      = 'KLIEN - Sambungkan ke printer yang dibagikan'
        clientOsNote      = 'OS klien ini: {0}'
        clientItemList    = 'Lihat printer yang dibagikan di host'
        clientItemConnect = 'Sambungkan ke printer host'
        clientItemRepair  = 'Sambungkan ulang / perbaiki (Repair)'
        clientItemBatch   = 'Sambung cepat via batch (khusus Win7 64-bit)'
        clientItemLocal   = 'Mode LocalPort + driver 32-bit (khusus Win7 32-bit)'
        onlyWin7          = 'Pilihan hanya untuk Windows 7.'
        qDriverInf        = 'Path file driver 32-bit (.inf)'
        driverRequired    = 'DriverInf wajib untuk mode LocalPort.'
        qSetDefault       = 'Jadikan printer default?'
        qTestPage         = 'Cetak halaman uji setelah tersambung?'
        qSaveCred         = 'Simpan kredensial (bila host minta login)?'
        qCompatFix        = 'Terapkan fix kompatibilitas RPC (error 0x0000011b)?'

        diagHeader  = 'DIAGNOSA - Cek masalah sharing (read-only)'
        diagNote1   = 'Kosongkan nama host bila ingin memeriksa PC ini sendiri.'
        diagNote2   = 'Jalankan di HOST dan di KLIEN untuk membandingkan hasil.'
        qServer     = 'Nama/IP host (Enter = PC ini)'
        qShareOpt   = 'Nama share printer (opsional)'
        qPrinterOpt = 'Nama printer lokal untuk cek driver (opsional)'

        fixHeader    = 'PERBAIKAN - Kompatibilitas Windows 7'
        fixNote1     = 'Menyetel ulang RpcAuthnLevelPrivacyEnabled dan kebijakan Point and Print'
        fixNote2     = 'pada PC ini (biasanya di HOST) untuk mengatasi error 0x0000011b'
        fixNote3     = 'dan 0x00000bc4 dari klien lama.'
        qFixLegacy   = 'Aktifkan mode kompatibel Windows 7 (menurunkan keamanan)?'
        qFixGuest    = 'Sekaligus izinkan akses tanpa password (guest)?'
        noChanges    = 'Tidak ada perubahan.'

        rbHeader    = 'ROLLBACK - Kembalikan pengaturan host'
        rbScript    = 'Script: {0}'
        rbNote      = 'Kosongkan path file untuk memakai cadangan terbaru.'
        qRbFile     = 'Path file backup/journal (opsional)'
        qRbConfirm  = 'Lanjutkan rollback?'

        logHeader    = 'LOG & BACKUP'
        logDir       = 'Folder: {0}'
        logEmpty     = 'Belum ada file log/backup.'
        logLatest    = 'File terbaru:'
        qOpenFolder  = 'Buka folder di Explorer?'
        qShowLog     = 'Tampilkan isi log terbaru?'
        logNone      = 'Tidak ada file log.'
        linesSuffix  = 'baris'

        helpHeader   = 'PANDUAN SINGKAT'
        helpBody     = @'
  Urutan pemakaian yang disarankan:

   1. Di PC yang tercolok printer (HOST), pilih menu 1 lalu bagikan printer.
      Catat nama PC host dan nama share yang ditampilkan.

   2. Di PC lain (KLIEN), pilih menu 2 lalu sambungkan ke host tersebut.

   3. Bila bermasalah, jalankan menu 3 (DIAGNOSA).

   4. Ingin membatalkan? Menu 4 (PERBAIKAN) atau menu 5 (ROLLBACK).

  Panduan lengkap ada di README.md.
'@
        qOpenReadme  = 'Buka README di aplikasi default?'

        langHeader   = 'BAHASA'
        langCurrent  = 'Bahasa saat ini: {0}'
        langName     = 'Indonesia'
        langSet      = 'Bahasa diatur ke Indonesia.'
    }
    en = @{
        title          = 'PRINTER SHARING TOOLKIT'
        osLine         = 'This OS'
        shareStatus    = 'Shared printers'
        statusNone     = 'none yet'
        itemHost       = 'HOST      - Share a printer from this PC'
        itemClient     = 'CLIENT    - Connect to a shared printer'
        itemDiag       = 'DIAGNOSE  - Check sharing problems (read-only)'
        itemFix        = 'REPAIR    - Fix Windows 7 compatibility'
        itemRollback   = 'ROLLBACK  - Restore host settings'
        itemLogs       = 'LOGS      - View recent logs & backups'
        itemHelp       = 'HELP      - Quick guide & open README'
        itemLang       = 'LANGUAGE  - Switch language (ID/EN)'
        itemExit       = 'EXIT'
        choose         = 'Choose'
        unknownChoice  = 'Unknown choice.'
        cancelled      = 'Cancelled.'
        pressEnter     = 'Press Enter to return to the menu'
        invalidYesNo   = 'Answer y or n.'
        back           = 'Back'

        adminWarn1     = 'WARNING: this menu is not running as Administrator.'
        adminWarn2     = 'It is better to close it and run via Menu.cmd.'
        adminWarn3     = 'Press Enter to continue anyway'

        osWin7         = 'Windows 7'
        osWin8         = 'Windows 8/8.1 (not officially supported)'
        osWin10        = 'Windows 10'
        osWin11        = 'Windows 11'

        labelPickPrinter = 'Pick a number, or type the exact printer name (Enter = cancel)'
        noPrinters       = 'No printer detected on this PC.'
        detectedPrinters = 'Detected printers:'
        outOfRange       = 'Number out of range.'
        required         = '{0} is required.'
        qHost            = 'Host name/IP (without \\ )'
        qShare           = 'Printer share name (see host script output)'

        hostHeader     = 'HOST - Share a printer from this PC'
        hostScriptNote = 'Host script auto-selected for: {0}'
        hostItemList   = 'List printers on this PC'
        hostItemShare  = 'Share a printer (step by step)'
        hostItemDry    = 'Dry-run first (changes nothing)'
        hostItemUnshare = 'Stop sharing a printer (unshare)'
        dryRunNote     = 'SIMULATION mode (dry-run): nothing is changed.'
        qShareName     = 'Share name (optional, Enter = auto from printer name)'
        qSmb2          = 'Enable SMB2 if it is disabled?'
        qLegacy        = 'Any Windows 7 clients on the network? (lowers security)'
        qGuest         = 'Allow password-less access (guest)?'
        qNetbios       = 'Enable NetBIOS (helps Win7 find this PC)?'
        qEveryone      = 'Allow everyone to print (Everyone: Print)?'
        qApply         = 'Apply now?'
        hostNotShared  = 'No printer is currently shared.'
        sharedPrinters = 'Currently shared printers:'
        qUnshare       = 'Stop sharing this printer?'
        unshareDone    = 'Stopped sharing the printer.'
        unshareFail    = 'Failed to stop sharing (code {0}).'

        clientHeader      = 'CLIENT - Connect to a shared printer'
        clientOsNote      = 'This client OS: {0}'
        clientItemList    = 'List printers shared on the host'
        clientItemConnect = 'Connect to a host printer'
        clientItemRepair  = 'Reconnect / repair (Repair)'
        clientItemBatch   = 'Quick connect via batch (Win7 64-bit only)'
        clientItemLocal   = 'LocalPort mode + 32-bit driver (Win7 32-bit only)'
        onlyWin7          = 'This option is for Windows 7 only.'
        qDriverInf        = 'Path to 32-bit driver file (.inf)'
        driverRequired    = 'DriverInf is required for LocalPort mode.'
        qSetDefault       = 'Set as the default printer?'
        qTestPage         = 'Print a test page after connecting?'
        qSaveCred         = 'Save credentials (if the host asks for login)?'
        qCompatFix        = 'Apply RPC compatibility fix (error 0x0000011b)?'

        diagHeader  = 'DIAGNOSE - Check sharing problems (read-only)'
        diagNote1   = 'Leave the host empty to check this PC itself.'
        diagNote2   = 'Run on both HOST and CLIENT to compare results.'
        qServer     = 'Host name/IP (Enter = this PC)'
        qShareOpt   = 'Printer share name (optional)'
        qPrinterOpt = 'Local printer name to check the driver (optional)'

        fixHeader    = 'REPAIR - Windows 7 compatibility'
        fixNote1     = 'Resets RpcAuthnLevelPrivacyEnabled and the Point and Print policy'
        fixNote2     = 'on this PC (usually the HOST) to fix errors 0x0000011b'
        fixNote3     = 'and 0x00000bc4 from legacy clients.'
        qFixLegacy   = 'Enable Windows 7 compatible mode (lowers security)?'
        qFixGuest    = 'Also allow password-less access (guest)?'
        noChanges    = 'No changes.'

        rbHeader    = 'ROLLBACK - Restore host settings'
        rbScript    = 'Script: {0}'
        rbNote      = 'Leave the file path empty to use the latest backup.'
        qRbFile     = 'Backup/journal file path (optional)'
        qRbConfirm  = 'Proceed with the rollback?'

        logHeader    = 'LOGS & BACKUPS'
        logDir       = 'Folder: {0}'
        logEmpty     = 'No log/backup files yet.'
        logLatest    = 'Latest files:'
        qOpenFolder  = 'Open the folder in Explorer?'
        qShowLog     = 'Show the latest log content?'
        logNone      = 'No log file found.'
        linesSuffix  = 'lines'

        helpHeader   = 'QUICK GUIDE'
        helpBody     = @'
  Recommended order:

   1. On the PC with the printer attached (HOST), choose 1 and share it.
      Note the host PC name and the share name it prints.

   2. On the other PC (CLIENT), choose 2 and connect to that host.

   3. If something fails, run 3 (DIAGNOSE).

   4. To undo, use 4 (REPAIR) or 5 (ROLLBACK).

  The full guide is in README.md.
'@
        qOpenReadme  = 'Open README in the default app?'

        langHeader   = 'LANGUAGE'
        langCurrent  = 'Current language: {0}'
        langName     = 'English'
        langSet      = 'Language set to English.'
    }
}

function T {
    param([string]$Key)
    $table = $Script:Strings[$Script:Lang]
    if ($table -and $table.ContainsKey($Key)) { return $table[$Key] }
    $fallback = $Script:Strings['id']
    if ($fallback -and $fallback.ContainsKey($Key)) { return $fallback[$Key] }
    return $Key
}

function Save-Lang {
    try {
        $dir = Split-Path -Parent $Script:LangFile
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -LiteralPath $Script:LangFile -Value $Script:Lang -Encoding ASCII
    }
    catch { }
}

if (Test-Path -LiteralPath $Script:LangFile) {
    try {
        $savedLang = (Get-Content -LiteralPath $Script:LangFile | Select-Object -First 1)
        if ($savedLang -and ([string]$savedLang).Trim() -eq 'en') { $Script:Lang = 'en' }
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
        'Win7'  { return (T 'osWin7') }
        'Win8'  { return (T 'osWin8') }
        'Win11' { return (T 'osWin11') }
        default { return (T 'osWin10') }
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
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ('  ' + $Text) -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Pause-Menu {
    Write-Host ''
    [void](Read-Host ('  ' + (T 'pressEnter')))
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
        Write-Host ('  ' + (T 'invalidYesNo')) -ForegroundColor Yellow
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
        Write-Host ('  [ERROR] ' + $Path) -ForegroundColor Red
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
# Printer: daftar lokal, printer yang dibagikan, status
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

function Get-SharedPrinters {
    $out = New-Object System.Collections.ArrayList
    if (Get-Command Get-Printer -ErrorAction SilentlyContinue) {
        foreach ($p in @(Get-Printer -ErrorAction SilentlyContinue)) {
            if ($p.Shared) {
                [void]$out.Add((New-Object PSObject -Property @{ Name = [string]$p.Name; ShareName = [string]$p.ShareName }))
            }
        }
    }
    else {
        foreach ($p in @(Get-WmiObject -Class Win32_Printer -ErrorAction SilentlyContinue)) {
            if ($p.Shared) {
                [void]$out.Add((New-Object PSObject -Property @{ Name = [string]$p.Name; ShareName = [string]$p.ShareName }))
            }
        }
    }
    return @($out)
}

function Get-ShareStatusText {
    $shared = @(Get-SharedPrinters)
    $names = @()
    foreach ($p in $shared) {
        if ($p.ShareName) { $names += $p.ShareName } else { $names += $p.Name }
    }
    if ($names.Count -eq 0) { return (T 'statusNone') }
    return ($names -join ', ')
}

function Select-PrinterName {
    $names = @(Get-LocalPrinterNames)
    Write-Host ''
    if ($names.Count -eq 0) {
        Write-Host ('  ' + (T 'noPrinters')) -ForegroundColor Yellow
        return $null
    }
    Write-Host ('  ' + (T 'detectedPrinters')) -ForegroundColor Cyan
    for ($i = 0; $i -lt $names.Count; $i++) {
        Write-Host ('    ' + ($i + 1) + '. ' + $names[$i])
    }
    Write-Host ''
    $a = Read-Host ('  ' + (T 'labelPickPrinter'))
    if ($null -eq $a) { return $null }
    $a = $a.Trim()
    if ($a -eq '') { return $null }
    if ($a -match '^[0-9]+$') {
        $idx = [int]$a - 1
        if ($idx -ge 0 -and $idx -lt $names.Count) { return $names[$idx] }
        Write-Host ('  ' + (T 'outOfRange')) -ForegroundColor Yellow
        return $null
    }
    return $a
}

# ---------------------------------------------------------------------------
# Menu utama
# ---------------------------------------------------------------------------
function Show-MainMenu {
    Clear-Host
    if ($null -eq $Script:ShareStatus) { $Script:ShareStatus = Get-ShareStatusText }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ('        ' + (T 'title') + '  v' + $Script:Version) -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ('  ' + (T 'osLine') + ' : ' + (Get-OsLabel) + ' ' + $Script:ArchBits) -ForegroundColor Gray
    Write-Host ('  ' + (T 'shareStatus') + ' : ' + $Script:ShareStatus) -ForegroundColor Gray
    Write-Host ''
    Write-Host ('   1. ' + (T 'itemHost'))
    Write-Host ('   2. ' + (T 'itemClient'))
    Write-Host ('   3. ' + (T 'itemDiag'))
    Write-Host ('   4. ' + (T 'itemFix'))
    Write-Host ('   5. ' + (T 'itemRollback'))
    Write-Host ('   6. ' + (T 'itemLogs'))
    Write-Host ('   7. ' + (T 'itemHelp'))
    Write-Host ('   8. ' + (T 'itemLang'))
    Write-Host ('   0. ' + (T 'itemExit'))
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Menu HOST
# ---------------------------------------------------------------------------
function Start-HostSharing {
    param([bool]$DryRun = $false)

    Clear-Host
    Write-Header (T 'hostHeader')
    if ($DryRun) {
        Write-Host ('  ' + (T 'dryRunNote')) -ForegroundColor Yellow
        Write-Host ''
    }

    $printer = Select-PrinterName
    if (-not $printer) { Write-Host ('  ' + (T 'cancelled')) -ForegroundColor Yellow; Pause-Menu; return }

    $share = Read-Text ('  ' + (T 'qShareName'))

    $toolArgs = @{ PrinterName = $printer }
    if ($share -ne '') { $toolArgs['ShareName'] = $share }

    if ($Script:OsFamily -eq 'Win7') {
        if (Read-YesNo ('  ' + (T 'qSmb2')) $false) { $toolArgs['EnableSMB2'] = $true }
    }
    else {
        $legacy = Read-YesNo ('  ' + (T 'qLegacy')) $false
        if ($legacy) {
            $toolArgs['AllowLegacyWin7'] = $true
            if (Read-YesNo ('    ' + (T 'qGuest')) $false) { $toolArgs['AllowGuest'] = $true }
            if (Read-YesNo ('    ' + (T 'qNetbios')) $false) { $toolArgs['EnableNetBios'] = $true }
        }
        if (Read-YesNo ('  ' + (T 'qEveryone')) $false) { $toolArgs['GrantEveryonePrint'] = $true }
    }

    if ($DryRun) {
        $toolArgs['WhatIf'] = $true
    }
    elseif (-not (Read-YesNo ('  ' + (T 'qApply')) $true)) {
        Write-Host ('  ' + (T 'cancelled')) -ForegroundColor Yellow
        Pause-Menu
        return
    }

    Invoke-Tool (Get-HostScript) $toolArgs
    $Script:ShareStatus = $null
}

function Stop-HostSharing {
    Clear-Host
    Write-Header (T 'hostItemUnshare')

    $shared = @(Get-SharedPrinters)
    if ($shared.Count -eq 0) {
        Write-Host ('  ' + (T 'hostNotShared')) -ForegroundColor Yellow
        Pause-Menu
        return
    }

    Write-Host ('  ' + (T 'sharedPrinters')) -ForegroundColor Cyan
    for ($i = 0; $i -lt $shared.Count; $i++) {
        Write-Host ('    ' + ($i + 1) + '. ' + $shared[$i].Name + '  [' + $shared[$i].ShareName + ']')
    }
    Write-Host ''

    $a = Read-Host ('  ' + (T 'labelPickPrinter'))
    if ($null -eq $a) { return }
    $a = $a.Trim()
    if ($a -eq '' -or -not ($a -match '^[0-9]+$')) { Write-Host ('  ' + (T 'cancelled')) -ForegroundColor Yellow; Pause-Menu; return }

    $idx = [int]$a - 1
    if ($idx -lt 0 -or $idx -ge $shared.Count) {
        Write-Host ('  ' + (T 'outOfRange')) -ForegroundColor Yellow
        Pause-Menu
        return
    }

    $target = $shared[$idx]
    if (-not (Read-YesNo ('  ' + (T 'qUnshare')) $false)) {
        Write-Host ('  ' + (T 'cancelled')) -ForegroundColor Yellow
        Pause-Menu
        return
    }

    $ok = $false
    $code = ''
    if (Get-Command Set-Printer -ErrorAction SilentlyContinue) {
        try {
            Set-Printer -Name $target.Name -Shared $false -ErrorAction Stop
            $ok = $true
        }
        catch {
            $code = $_.Exception.Message
        }
    }
    else {
        if ($target.ShareName) {
            & net share $target.ShareName /delete | Out-Null
            $code = [string]$LASTEXITCODE
            if ($LASTEXITCODE -eq 0) { $ok = $true }
        }
        else {
            $code = 'no-share-name'
        }
    }

    Write-Host ''
    if ($ok) { Write-Host ('  ' + (T 'unshareDone')) -ForegroundColor Green }
    else { Write-Host ('  ' + ((T 'unshareFail') -f $code)) -ForegroundColor Red }

    $Script:ShareStatus = $null
    Pause-Menu
}

function Show-HostMenu {
    while ($true) {
        Clear-Host
        Write-Header (T 'hostHeader')
        Write-Host ('  ' + ((T 'hostScriptNote') -f (Get-OsLabel)))
        Write-Host ''
        Write-Host ('   1. ' + (T 'hostItemList'))
        Write-Host ('   2. ' + (T 'hostItemShare'))
        Write-Host ('   3. ' + (T 'hostItemDry'))
        Write-Host ('   4. ' + (T 'hostItemUnshare'))
        Write-Host ('   0. ' + (T 'back'))
        Write-Host ''
        $c = Read-Host ('  ' + (T 'choose'))
        if ($null -eq $c) { return }
        switch ($c.Trim()) {
            '1' { Invoke-Tool (Get-HostScript) @{ ListPrinters = $true } }
            '2' { Start-HostSharing $false }
            '3' { Start-HostSharing $true }
            '4' { Stop-HostSharing }
            '0' { return }
            default { Write-Host ('  ' + (T 'unknownChoice')) -ForegroundColor Yellow }
        }
    }
}

# ---------------------------------------------------------------------------
# Menu KLIEN
# ---------------------------------------------------------------------------
function Start-Win7Batch {
    Clear-Host
    Write-Header (T 'clientItemBatch')

    $server = Read-Text ('  ' + (T 'qHost'))
    if ($server -eq '') { Write-Host ('  ' + ((T 'required') -f (T 'qHost'))) -ForegroundColor Yellow; Pause-Menu; return }

    $share = Read-Text ('  ' + (T 'qShare'))
    if ($share -eq '') { Write-Host ('  ' + ((T 'required') -f (T 'qShare'))) -ForegroundColor Yellow; Pause-Menu; return }

    $testStr = '-'
    if (Read-YesNo ('  ' + (T 'qTestPage')) $false) { $testStr = 'test' }
    $repairStr = '-'
    if (Read-YesNo ('  ' + (T 'clientItemRepair')) $false) { $repairStr = 'repair' }

    $cmdPath = Join-Path $Script:Root 'client\Win7\02-Connect-Win7.cmd'
    Invoke-Tool $cmdPath @($server, $share, '-', '-', $testStr, $repairStr)
}

function Start-ClientConnect {
    param([string]$Action, [switch]$LocalPort)

    Clear-Host
    Write-Header (T 'clientItemConnect')
    $scriptPath = Get-ClientScript

    $server = Read-Text ('  ' + (T 'qHost'))
    if ($server -eq '') { Write-Host ('  ' + ((T 'required') -f (T 'qHost'))) -ForegroundColor Yellow; Pause-Menu; return }

    if ($Action -eq 'list') {
        Invoke-Tool $scriptPath @{ Server = $server; ListRemote = $true }
        return
    }

    $share = Read-Text ('  ' + (T 'qShare'))
    if ($share -eq '') { Write-Host ('  ' + ((T 'required') -f (T 'qShare'))) -ForegroundColor Yellow; Pause-Menu; return }

    $toolArgs = @{ Server = $server; ShareName = $share }
    if ($Action -eq 'repair') { $toolArgs['Repair'] = $true }

    if ($LocalPort) {
        $inf = Read-Text ('  ' + (T 'qDriverInf'))
        if ($inf -eq '') { Write-Host ('  ' + (T 'driverRequired')) -ForegroundColor Yellow; Pause-Menu; return }
        $toolArgs['Mode'] = 'LocalPort'
        $toolArgs['DriverInf'] = $inf
    }
    else {
        if (Read-YesNo ('  ' + (T 'qSetDefault')) $true) { $toolArgs['SetDefault'] = $true }
        if (Read-YesNo ('  ' + (T 'qTestPage')) $false) { $toolArgs['TestPage'] = $true }
        if (Read-YesNo ('  ' + (T 'qSaveCred')) $false) { $toolArgs['SaveCredential'] = $true }
        if ($Script:OsFamily -ne 'Win7') {
            if (Read-YesNo ('  ' + (T 'qCompatFix')) $false) { $toolArgs['ApplyCompatFix'] = $true }
        }
    }

    Invoke-Tool $scriptPath $toolArgs
}

function Show-ClientMenu {
    while ($true) {
        Clear-Host
        Write-Header (T 'clientHeader')
        Write-Host ('  ' + ((T 'clientOsNote') -f ((Get-OsLabel) + ' ' + $Script:ArchBits)))
        Write-Host ''
        Write-Host ('   1. ' + (T 'clientItemList'))
        Write-Host ('   2. ' + (T 'clientItemConnect'))
        Write-Host ('   3. ' + (T 'clientItemRepair'))
        if ($Script:OsFamily -eq 'Win7') {
            Write-Host ('   4. ' + (T 'clientItemBatch'))
            Write-Host ('   5. ' + (T 'clientItemLocal'))
        }
        Write-Host ('   0. ' + (T 'back'))
        Write-Host ''
        $c = Read-Host ('  ' + (T 'choose'))
        if ($null -eq $c) { return }
        switch ($c.Trim()) {
            '1' { Start-ClientConnect -Action 'list' }
            '2' { Start-ClientConnect -Action 'connect' }
            '3' { Start-ClientConnect -Action 'repair' }
            '4' {
                if ($Script:OsFamily -eq 'Win7') { Start-Win7Batch }
                else { Write-Host ('  ' + (T 'onlyWin7')) -ForegroundColor Yellow }
            }
            '5' {
                if ($Script:OsFamily -eq 'Win7') { Start-ClientConnect -Action 'connect' -LocalPort }
                else { Write-Host ('  ' + (T 'onlyWin7')) -ForegroundColor Yellow }
            }
            '0' { return }
            default { Write-Host ('  ' + (T 'unknownChoice')) -ForegroundColor Yellow }
        }
    }
}

# ---------------------------------------------------------------------------
# Menu DIAGNOSA
# ---------------------------------------------------------------------------
function Show-DiagMenu {
    Clear-Host
    Write-Header (T 'diagHeader')
    Write-Host ('  ' + (T 'diagNote1')) -ForegroundColor Gray
    Write-Host ('  ' + (T 'diagNote2')) -ForegroundColor Gray
    Write-Host ''

    $server = Read-Text ('  ' + (T 'qServer'))
    $share = Read-Text ('  ' + (T 'qShareOpt'))
    $printer = Read-Text ('  ' + (T 'qPrinterOpt'))

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
    Write-Header (T 'fixHeader')
    Write-Host ('  ' + (T 'fixNote1'))
    Write-Host ('  ' + (T 'fixNote2'))
    Write-Host ('  ' + (T 'fixNote3')) -ForegroundColor Gray
    Write-Host ''

    if (-not (Read-YesNo ('  ' + (T 'qFixLegacy')) $true)) {
        Write-Host ('  ' + (T 'noChanges')) -ForegroundColor Yellow
        Pause-Menu
        return
    }

    $toolArgs = @{ AllowLegacyWin7 = $true }
    if (Read-YesNo ('  ' + (T 'qFixGuest')) $false) { $toolArgs['AllowGuest'] = $true }

    Invoke-Tool (Join-Path $Script:Root 'tools\04-Fix-LegacyCompat.ps1') $toolArgs
}

# ---------------------------------------------------------------------------
# Menu ROLLBACK
# ---------------------------------------------------------------------------
function Show-RollbackMenu {
    Clear-Host
    Write-Header (T 'rbHeader')

    if ($Script:OsFamily -eq 'Win7') {
        $scriptPath = Join-Path $Script:Root 'tools\05-Rollback-Win7.ps1'
        $fileParam = 'JournalFile'
        $scriptName = '05-Rollback-Win7.ps1'
    }
    else {
        $scriptPath = Join-Path $Script:Root 'tools\05-Rollback.ps1'
        $fileParam = 'BackupFile'
        $scriptName = '05-Rollback.ps1'
    }
    Write-Host ('  ' + ((T 'rbScript') -f $scriptName)) -ForegroundColor Gray
    Write-Host ('  ' + (T 'rbNote')) -ForegroundColor Gray
    Write-Host ''

    $file = Read-Text ('  ' + (T 'qRbFile'))

    if (-not (Read-YesNo ('  ' + (T 'qRbConfirm')) $false)) {
        Write-Host ('  ' + (T 'cancelled')) -ForegroundColor Yellow
        Pause-Menu
        return
    }

    $toolArgs = @{}
    if ($file -ne '') { $toolArgs[$fileParam] = $file }

    Invoke-Tool $scriptPath $toolArgs
    $Script:ShareStatus = $null
}

# ---------------------------------------------------------------------------
# Menu LOG & BACKUP
# ---------------------------------------------------------------------------
function Show-LogsMenu {
    $dir = Join-Path $env:ProgramData 'PrinterShare\logs'
    while ($true) {
        Clear-Host
        Write-Header (T 'logHeader')
        Write-Host ('  ' + ((T 'logDir') -f $dir)) -ForegroundColor Gray
        Write-Host ''

        $items = @()
        if (Test-Path -LiteralPath $dir) {
            $items = @(Get-ChildItem -LiteralPath $dir |
                       Where-Object { -not $_.PSIsContainer } |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 10)
        }

        if ($items.Count -eq 0) {
            Write-Host ('  ' + (T 'logEmpty')) -ForegroundColor Yellow
        }
        else {
            Write-Host ('  ' + (T 'logLatest')) -ForegroundColor Cyan
            foreach ($it in $items) {
                Write-Host ('    {0}  {1,9}  {2}' -f $it.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $it.Length, $it.Name)
            }
        }

        Write-Host ''
        Write-Host ('   1. ' + (T 'qOpenFolder'))
        Write-Host ('   2. ' + (T 'qShowLog'))
        Write-Host ('   0. ' + (T 'back'))
        Write-Host ''
        $c = Read-Host ('  ' + (T 'choose'))
        if ($null -eq $c) { return }

        switch ($c.Trim()) {
            '1' {
                if (Test-Path -LiteralPath $dir) {
                    try { Start-Process -FilePath 'explorer.exe' -ArgumentList $dir } catch { }
                }
                else {
                    Write-Host ('  ' + (T 'logEmpty')) -ForegroundColor Yellow
                    Pause-Menu
                }
            }
            '2' {
                $latest = $null
                if (Test-Path -LiteralPath $dir) {
                    $latest = Get-ChildItem -LiteralPath $dir -Filter '*.log' |
                              Sort-Object LastWriteTime -Descending |
                              Select-Object -First 1
                }
                Clear-Host
                if ($latest) {
                    Write-Header $latest.Name
                    $lines = @(Get-Content -LiteralPath $latest.FullName)
                    $tail = @($lines | Select-Object -Last 40)
                    foreach ($l in $tail) { Write-Host $l }
                    Write-Host ''
                    Write-Host ('  ({0} {1})' -f $lines.Count, (T 'linesSuffix')) -ForegroundColor DarkGray
                }
                else {
                    Write-Host ('  ' + (T 'logNone')) -ForegroundColor Yellow
                }
                Pause-Menu
            }
            '0' { return }
            default { Write-Host ('  ' + (T 'unknownChoice')) -ForegroundColor Yellow }
        }
    }
}

# ---------------------------------------------------------------------------
# Menu BANTUAN
# ---------------------------------------------------------------------------
function Show-HelpMenu {
    Clear-Host
    Write-Header (T 'helpHeader')
    foreach ($line in ((T 'helpBody') -split "\r?\n")) { Write-Host $line }
    Write-Host ''

    if (Read-YesNo ('  ' + (T 'qOpenReadme')) $false) {
        $readme = Join-Path $Script:Root 'README.md'
        try { Start-Process -FilePath $readme }
        catch { Write-Host ('  ' + $readme) -ForegroundColor Gray }
    }
}

# ---------------------------------------------------------------------------
# Menu BAHASA
# ---------------------------------------------------------------------------
function Show-LangMenu {
    Clear-Host
    Write-Header (T 'langHeader')
    Write-Host ('  ' + ((T 'langCurrent') -f (T 'langName')))
    Write-Host ''
    Write-Host '   1. Indonesia'
    Write-Host '   2. English'
    Write-Host ''
    $c = Read-Host ('  ' + (T 'choose'))
    if ($null -eq $c) { return }
    switch ($c.Trim()) {
        '1' { $Script:Lang = 'id'; Save-Lang }
        '2' { $Script:Lang = 'en'; Save-Lang }
        default { return }
    }
    Write-Host ('  ' + (T 'langSet')) -ForegroundColor Green
    Start-Sleep -Seconds 1
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
    $Script:ShareStatus = $null

    if (-not (Test-IsAdmin)) {
        Write-Host ''
        Write-Host ('  ' + (T 'adminWarn1')) -ForegroundColor Yellow
        Write-Host ('  ' + (T 'adminWarn2')) -ForegroundColor Yellow
        [void](Read-Host ('  ' + (T 'adminWarn3')))
    }

    while ($true) {
        Show-MainMenu
        $c = Read-Host ('  ' + (T 'choose'))
        if ($null -eq $c) { return }
        switch ($c.Trim()) {
            '1' { Show-HostMenu }
            '2' { Show-ClientMenu }
            '3' { Show-DiagMenu }
            '4' { Show-FixMenu }
            '5' { Show-RollbackMenu }
            '6' { Show-LogsMenu }
            '7' { Show-HelpMenu }
            '8' { Show-LangMenu }
            '0' { return }
            default { Write-Host ('  ' + (T 'unknownChoice')) -ForegroundColor Yellow }
        }
    }
}

# Jalankan menu hanya bila TIDAK di-dot-source (agar bisa diuji).
if ($MyInvocation.InvocationName -ne '.') {
    Start-Menu
    exit 0
}
