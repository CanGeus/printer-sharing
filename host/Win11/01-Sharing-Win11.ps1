#Requires -Version 5.1
<#
.SYNOPSIS
    HOST Windows 11 - share printer USB agar bisa dipakai PC lain.

.DESCRIPTION
    Khusus dijalankan di PC Windows 11 yang menempel printer (USB).
    Untuk host Windows 10 pakai ..\Win10\01-Sharing-Win10.ps1.
    Untuk host Windows 7 pakai ..\Win7\01-Sharing-Win7.ps1.

    Catatan khusus Windows 11:
      - Build 24H2 (26100+) membatasi driver v3 lama dan mengabaikan
        AllowInsecureGuestAuth. Klien Win7 sebaiknya pakai akun berpassword.
      - Windows Protected Print Mode harus MATI agar sharing legacy bekerja.
        Script ini mendeteksinya dan memberi peringatan.

    Yang dilakukan:
      1. Profil jaringan -> Private
      2. Firewall grup File and Printer Sharing + Network Discovery
      3. Layanan Spooler / LanmanServer / FDResPub / fdPHost / SSDPSRV / upnphost
      4. SMB2 dipastikan aktif (SMB1 tetap mati)
      5. (opsional) fix kompatibilitas Windows 7
      6. Share printer + permission
      7. Verifikasi

.PARAMETER PrinterName
    Nama printer persis di "Printers & scanners". Lihat dulu dengan -ListPrinters.

.PARAMETER ShareName
    Nama share. Default diturunkan dari nama printer: tanpa spasi, maks 12 karakter.

.PARAMETER AllowLegacyWin7
    MENURUNKAN KEAMANAN. Diperlukan bila ada klien Windows 7.
    Menyetel RpcAuthnLevelPrivacyEnabled=0 dan Point and Print policy.

.PARAMETER AllowGuest
    Tambahan untuk akses tanpa password. Butuh -AllowLegacyWin7.

.PARAMETER GrantEveryonePrint
    Set permission share menjadi Everyone: Print.

.PARAMETER EnableNetBios
    Aktifkan NetBIOS over TCP/IP agar nama PC mudah ditemukan dari Windows 7.

.EXAMPLE
    .\01-Sharing-Win11.ps1 -ListPrinters

.EXAMPLE
    .\01-Sharing-Win11.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7 -WhatIf

.EXAMPLE
    .\01-Sharing-Win11.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$PrinterName,
    [string]$ShareName,
    [switch]$AllowLegacyWin7,
    [switch]$AllowGuest,
    [switch]$GrantEveryonePrint,
    [switch]$EnableNetBios,
    [switch]$SkipNetworkProfile,
    [switch]$SkipFirewall,
    [switch]$ListPrinters,
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'
$script:LogRoot = Join-Path $env:ProgramData 'PrinterShare\logs'

# Muat modul CimCmdlets sekali di luar mode -WhatIf, supaya tidak muncul
# derau "What if: Performing the operation 'Set Alias'" saat -WhatIf dipakai.
$__wf = $WhatIfPreference
$WhatIfPreference = $false
try { Import-Module CimCmdlets -ErrorAction SilentlyContinue } catch { }
$WhatIfPreference = $__wf
Remove-Variable __wf -ErrorAction SilentlyContinue

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ----------------------------------------------------------------------------
# Info printer (bisa tanpa Administrator)
# ----------------------------------------------------------------------------
if ($ListPrinters) {
    Write-Host ''
    Write-Host 'Printer di komputer ini:' -ForegroundColor Cyan
    Get-Printer |
    Select-Object Name, DriverName,
    @{ n = 'Port'; e = {
            $p = [string]$_.PortName
            if ($p.StartsWith('\\')) { '<remote> ' + $p }
            elseif ($p.Length -gt 40) { $p.Substring(0, 40) + '...' }
            else { $p }
        } 
    },
    Type, Shared, ShareName |
    Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    Write-Host 'Kandidat share: Type = Local dan Port USBxxx / LPTx / DOT4 / TCPIP.' -ForegroundColor Gray
    Write-Host ''
    exit 0
}

if (-not (Test-IsAdmin)) {
    Write-Host ''
    Write-Host 'Jalankan sebagai Administrator.' -ForegroundColor Red
    Write-Host 'Klik kanan PowerShell -> Run as administrator, lalu ulangi.' -ForegroundColor Yellow
    Write-Host '(Tip: -ListPrinters bisa tanpa Administrator.)' -ForegroundColor Gray
    Write-Host ''
    exit 1
}

if (-not (Test-Path -LiteralPath $script:LogRoot)) {
    New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
}
$transcript = Join-Path $script:LogRoot ('Win11-host-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (-not $BackupPath) {
    $BackupPath = Join-Path $script:LogRoot ('Win11-backup-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$script:BackupPath = $BackupPath
try { Start-Transcript -Path $transcript -Force | Out-Null } catch { }

$script:Backup = [ordered]@{
    Created         = (Get-Date).ToString('o')
    Computer        = $env:COMPUTERNAME
    HostOS          = 'Windows 11'
    NetworkProfiles = @()
    Services        = @()
    FirewallRules   = @()
    Printers        = @()
    Registry        = @()
}

function Save-Backup {
    try {
        $script:Backup | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:BackupPath -Encoding UTF8
    }
    catch {
        Write-Host ('[WARN] Gagal simpan backup: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

$script:Results = New-Object System.Collections.ArrayList
function Add-Result {
    param(
        [string]$Step,
        [ValidateSet('OK', 'WARN', 'FAIL', 'SKIP', 'INFO')][string]$Status,
        [string]$Detail
    )
    [void]$script:Results.Add([pscustomobject]@{ Step = $Step; Status = $Status; Detail = $Detail })
    $color = switch ($Status) { 'OK' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } 'SKIP' { 'DarkGray' } default { 'Gray' } }
    Write-Host ('[{0}] {1}' -f $Status, $Step) -ForegroundColor $color -NoNewline
    if ($Detail) { Write-Host (' - {0}' -f $Detail) -ForegroundColor DarkGray } else { Write-Host '' }
}

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
function Set-ServiceState {
    param([string]$Name, [string]$DesiredStart)

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Add-Result ("Layanan {0}" -f $Name) 'WARN' 'Tidak tersedia'
        return
    }
    $wmi = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $Name)
    $currentStart = switch ([string]$wmi.StartMode) {
        'Auto' { 'Automatic' } 'Manual' { 'Manual' } default { [string]$wmi.StartMode }
    }
    $script:Backup.Services += [pscustomobject]@{ Name = $Name; StartType = $currentStart; Status = [string]$wmi.State }

    $touched = $false
    if ($currentStart -ne $DesiredStart -and $PSCmdlet.ShouldProcess($Name, "Startup -> $DesiredStart")) {
        Set-Service -Name $Name -StartupType $DesiredStart
        $touched = $true
    }
    if ($svc.Status -ne 'Running' -and $PSCmdlet.ShouldProcess($Name, 'Start service')) {
        try { Start-Service -Name $Name; $touched = $true }
        catch { Add-Result ("Layanan {0}" -f $Name) 'WARN' $_.Exception.Message; return }
    }
    if ($WhatIfPreference) { Add-Result ("Layanan {0}" -f $Name) 'SKIP' 'WhatIf' }
    elseif ($touched) { Add-Result ("Layanan {0}" -f $Name) 'OK' ("{0} / Running" -f $DesiredStart) }
    else { Add-Result ("Layanan {0}" -f $Name) 'OK' 'Sudah jalan' }
}

function Add-FirewallBackup {
    param([string]$RuleName)
    foreach ($r in $script:Backup.FirewallRules) { if ($r.Name -eq $RuleName) { return } }
    $script:Backup.FirewallRules += [pscustomobject]@{ Name = $RuleName }
}

function Set-RegValue {
    param([string]$Path, [string]$Name, [object]$Value, [string]$Type = 'DWord')

    $existed = $false; $oldValue = $null; $oldType = $null
    if (Test-Path -LiteralPath $Path) {
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            $existed = $true
            $oldValue = $item.$Name
            try { $oldType = (Get-Item -LiteralPath $Path).GetValueKind($Name).ToString() } catch { $oldType = $Type }
        }
    }
    elseif ($PSCmdlet.ShouldProcess($Path, 'Buat registry key')) {
        New-Item -Path $Path -Force | Out-Null
    }

    $script:Backup.Registry += [pscustomobject]@{
        Path = $Path; Name = $Name; Existed = $existed; OldValue = $oldValue; OldType = $oldType
    }

    if ($PSCmdlet.ShouldProcess(("{0}\{1}" -f $Path, $Name), ("Set {0} = {1}" -f $Name, $Value))) {
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        return $true
    }
    return $false
}

function Apply-LegacyFix {
    if (-not $AllowLegacyWin7 -and -not $AllowGuest) {
        Add-Result 'Kompatibilitas Win7' 'SKIP' 'Tidak diaktifkan (pakai -AllowLegacyWin7 bila ada klien Win7)'
        return
    }
    Write-Host ''
    Write-Host 'Fix kompatibilitas Windows 7 (menurunkan keamanan):' -ForegroundColor Yellow

    if ($AllowLegacyWin7) {
        if (Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' -Name 'RpcAuthnLevelPrivacyEnabled' -Value 0) {
            Add-Result 'RPC lama (0x0000011b)' 'OK' 'RpcAuthnLevelPrivacyEnabled = 0'
        }
        $pnp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
        if (Set-RegValue -Path $pnp -Name 'RestrictDriverInstallationToAdministrators' -Value 0) {
            Add-Result 'Point and Print (0x00000bc4)' 'OK' 'RestrictDriverInstallationToAdministrators = 0'
        }
        [void](Set-RegValue -Path $pnp -Name 'NoWarningNoElevationOnInstall' -Value 1)
        [void](Set-RegValue -Path $pnp -Name 'UpdatePromptSettings' -Value 2)
    }

    if ($AllowGuest) {
        [void](Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LimitBlankPasswordUse' -Value 0)
        [void](Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'AllowInsecureGuestAuth' -Value 1)
        [void](Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation' -Name 'AllowInsecureGuestAuth' -Value 1)
        Add-Result 'Akses guest' 'OK' 'LimitBlankPasswordUse=0, AllowInsecureGuestAuth=1'
    }
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
$script:Failed = $false

function Invoke-Main {

    $os = Get-CimInstance Win32_OperatingSystem
    Add-Result 'Sistem' 'INFO' ('{0} build {1} ({2})' -f $os.Caption, $os.BuildNumber, $os.OSArchitecture)
    if ([int]$os.BuildNumber -lt 22000) {
        throw 'Ini bukan Windows 11. Pakai host\Win10\01-Sharing-Win10.ps1'
    }
    if ([int]$os.BuildNumber -ge 26100) {
        Add-Result 'Windows 11 24H2+' 'WARN' 'Driver v3 lama dan akses guest makin dibatasi Microsoft'
    }

    $wpp = $null
    foreach ($k in @('HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\WPP',
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print')) {
        $v = Get-ItemProperty -LiteralPath $k -Name 'WindowsProtectedPrintMode' -ErrorAction SilentlyContinue
        if ($null -ne $v) { $wpp = $v.WindowsProtectedPrintMode; break }
    }
    if ($null -ne $wpp -and [int]$wpp -eq 1) {
        Add-Result 'Windows Protected Print' 'WARN' 'AKTIF - sharing legacy akan gagal. Matikan di Settings > Bluetooth & devices > Printers'
    }
    else {
        Add-Result 'Windows Protected Print' 'OK' 'Tidak aktif'
    }

    Add-Result 'Host' 'INFO' ('{0}  ->  \\{0}\<share>' -f $env:COMPUTERNAME)

    # 1. Profil jaringan
    if ($SkipNetworkProfile) {
        Add-Result 'Profil jaringan' 'SKIP' 'Dilewati'
    }
    else {
        $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
        if ($profiles.Count -eq 0) { Add-Result 'Profil jaringan' 'WARN' 'Tidak ada koneksi aktif' }
        foreach ($p in $profiles) {
            $script:Backup.NetworkProfiles += [pscustomobject]@{
                Name = $p.Name; InterfaceIndex = $p.InterfaceIndex; NetworkCategory = [string]$p.NetworkCategory
            }
            $label = 'Profil: {0}' -f $p.Name
            if ([string]$p.NetworkCategory -eq 'Private') { Add-Result $label 'OK' 'Sudah Private' }
            elseif ($PSCmdlet.ShouldProcess($p.Name, 'Set Private')) {
                Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private
                Add-Result $label 'OK' 'Diubah ke Private'
            }
            else { Add-Result $label 'SKIP' 'WhatIf' }
        }
    }

    # 2. Layanan
    Set-ServiceState 'Spooler' 'Automatic'
    Set-ServiceState 'LanmanServer' 'Automatic'
    Set-ServiceState 'FDResPub' 'Automatic'
    Set-ServiceState 'fdPHost' 'Manual'
    Set-ServiceState 'SSDPSRV' 'Automatic'
    Set-ServiceState 'upnphost' 'Manual'

    # 3. SMB
    $smb = Get-SmbServerConfiguration
    if (-not $smb.EnableSMB2Protocol) {
        if ($PSCmdlet.ShouldProcess('SMB', 'Aktifkan SMB2')) {
            Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force
            Add-Result 'SMB2' 'OK' 'Diaktifkan'
        }
        else { Add-Result 'SMB2' 'SKIP' 'WhatIf' }
    }
    else { Add-Result 'SMB2' 'OK' 'Sudah aktif' }
    if ($smb.EnableSMB1Protocol) { Add-Result 'SMB1' 'WARN' 'Masih aktif - sebaiknya dimatikan' }
    else { Add-Result 'SMB1' 'INFO' 'Nonaktif (sesuai rekomendasi)' }

    # 4. Firewall (ID grup locale-independent)
    if ($SkipFirewall) { Add-Result 'Firewall' 'SKIP' 'Dilewati' }
    else {
        $fwGroups = @(
            @{ Label = 'File and Printer Sharing'; Display = 'File and Printer Sharing'; Id = '@FirewallAPI.dll,-28502' },
            @{ Label = 'Network Discovery'; Display = 'Network Discovery'; Id = '@FirewallAPI.dll,-32752' }
        )
        foreach ($g in $fwGroups) {
            $rules = @(Get-NetFirewallRule -Group $g.Id -ErrorAction SilentlyContinue)
            if ($rules.Count -eq 0) { $rules = @(Get-NetFirewallRule -DisplayGroup $g.Display -ErrorAction SilentlyContinue) }
            $label = 'Firewall: {0}' -f $g.Label
            if ($rules.Count -eq 0) { Add-Result $label 'WARN' 'Grup rule tidak ditemukan'; continue }

            $disabled = @($rules | Where-Object { [string]$_.Enabled -eq 'False' -and [string]$_.Direction -eq 'Inbound' })
            foreach ($r in $disabled) { Add-FirewallBackup -RuleName $r.Name }

            if ($disabled.Count -eq 0) { Add-Result $label 'OK' ('{0} rule sudah aktif' -f $rules.Count) }
            elseif ($PSCmdlet.ShouldProcess($g.Label, 'Enable inbound')) {
                $disabled | Enable-NetFirewallRule
                Add-Result $label 'OK' ('{0} rule diaktifkan' -f $disabled.Count)
            }
            else { Add-Result $label 'SKIP' 'WhatIf' }
        }
    }

    # 5. NetBIOS opsional
    if ($EnableNetBios) {
        if ($PSCmdlet.ShouldProcess('NetBIOS', 'Aktifkan')) {
            $nics = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True')
            $n = 0
            foreach ($nic in $nics) {
                if ($nic.TcpipNetbiosOptions -ne 1) {
                    Invoke-CimMethod -InputObject $nic -MethodName SetTcpipNetbiosOptions -Arguments @{ TcpipNetbiosOptions = 1 } | Out-Null
                    $n++
                }
            }
            Add-Result 'NetBIOS' 'OK' ('{0} adapter diubah' -f $n)
        }
        else { Add-Result 'NetBIOS' 'SKIP' 'WhatIf' }
    }

    # 6. Fix Win7
    Apply-LegacyFix

    # 7. Pilih printer
    $excluded = 'Microsoft Print to PDF|Microsoft XPS Document Writer|^Fax$|OneNote|Root Print Queue|Send To'
    $candidates = @(Get-Printer | Where-Object {
            $_.Type -eq 'Local' -and $_.Name -notmatch $excluded -and
            $_.PortName -notmatch '^\\\\' -and $_.PortName -notmatch '^(PORTPROMPT:|SHRFAX:|nul:|FILE:)'
        })

    if ($PrinterName) {
        $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if (-not $printer) { throw ("Printer '{0}' tidak ditemukan. Pakai -ListPrinters." -f $PrinterName) }
        if ($printer.Type -ne 'Local') { throw ("'{0}' bukan printer lokal (Type={1})." -f $printer.Name, $printer.Type) }
        if ([string]$printer.PortName -match '^\\\\') {
            Add-Result 'Port printer' 'WARN' ('Mengarah ke PC lain: {0}' -f $printer.PortName)
        }
    }
    elseif ($candidates.Count -eq 1) { $printer = $candidates[0] }
    elseif ($candidates.Count -eq 0) { throw 'Tidak ada printer lokal. Colok printer USB dulu.' }
    else {
        $names = ($candidates | ForEach-Object { $_.Name }) -join ' | '
        throw ("Ada {0} kandidat: {1}. Tentukan dengan -PrinterName." -f $candidates.Count, $names)
    }
    Add-Result 'Printer terpilih' 'INFO' ('{0} [{1}]' -f $printer.Name, $printer.PortName)

    # 8. Driver
    $drv = Get-PrinterDriver -Name $printer.DriverName -ErrorAction SilentlyContinue
    $major = if ($drv) { $drv.MajorVersion } else { $null }
    if ($major -eq 4) {
        Add-Result 'Driver' 'WARN' ('{0} = Type 4, tidak kompatibel dengan Win7' -f $printer.DriverName)
        if ($AllowLegacyWin7 -and -not $WhatIfPreference) {
            throw 'Driver Type 4 tidak bisa dipakai Win7. Ganti ke driver Type 3 dulu.'
        }
    }
    else { Add-Result 'Driver' 'OK' ('{0} (v{1})' -f $printer.DriverName, $major) }

    # 9. Nama share
    $sanitized = $false
    if (-not $ShareName) {
        $raw = ($printer.Name -replace '[^\w\.\-]', '-') -replace '-{2,}', '-'
        $raw = $raw.Trim('-')
        if ($raw.Length -gt 12) { $raw = $raw.Substring(0, 12).Trim('-') }
        $ShareName = $raw; $sanitized = $true
    }
    else {
        $clean = $ShareName -replace '\s', '-'
        if ($clean -ne $ShareName) { $ShareName = $clean; $sanitized = $true }
    }
    if ($ShareName -notmatch '^[\w\.\-]{1,80}$') { throw ("ShareName '{0}' tidak valid." -f $ShareName) }

    $conflict = @(Get-Printer | Where-Object { $_.ShareName -eq $ShareName -and $_.Name -ne $printer.Name })
    if ($conflict.Count -gt 0) { throw ("Share name '{0}' sudah dipakai '{1}'." -f $ShareName, $conflict[0].Name) }

    Add-Result 'Nama share' 'OK' ('{0}{1}' -f $ShareName, $(if ($sanitized) { '  (dibersihkan)' } else { '' }))
    $unc = '\\{0}\{1}' -f $env:COMPUTERNAME, $ShareName

    # 10. Share
    $script:Backup.Printers += [pscustomobject]@{
        Name = $printer.Name; Shared = [bool]$printer.Shared; ShareName = $printer.ShareName; Published = [bool]$printer.Published
    }
    if ($PSCmdlet.ShouldProcess($printer.Name, ("Share sebagai '{0}'" -f $ShareName))) {
        Set-Printer -Name $printer.Name -Shared $true -ShareName $ShareName
        Add-Result 'Share printer' 'OK' $unc
        try { Set-Printer -Name $printer.Name -Published $true -ErrorAction Stop; Add-Result 'Publish direktori' 'OK' 'Aktif' }
        catch { Add-Result 'Publish direktori' 'SKIP' 'Tanpa domain AD (tidak masalah)' }
    }
    else { Add-Result 'Share printer' 'SKIP' 'WhatIf' }

    if ($GrantEveryonePrint -and $PSCmdlet.ShouldProcess($printer.Name, 'Permission Everyone: Print')) {
        $sddl = 'O:BAG:DUD:(A;;LCSWSDRCWDWO;;;BA)(A;;LCSWSDRCWDWO;;;CO)(A;;SWRC;;;PU)(A;;SWRC;;;ED)(A;;LCSWRCWDWO;;;SY)(A;;SWRC;;;WD)'
        Set-Printer -Name $printer.Name -PermissionSDDL $sddl
        Add-Result 'Permission Everyone' 'OK' 'Print diizinkan'
    }

    if (-not $WhatIfPreference) {
        Restart-Service -Name Spooler -Force
        Start-Sleep -Seconds 2
        Add-Result 'Restart Spooler' 'OK' 'Selesai'
    }

    # 11. Verifikasi
    if (-not $WhatIfPreference) {
        $after = Get-Printer -Name $printer.Name
        if ($after.Shared) { Add-Result 'Verifikasi share' 'OK' ('ShareName={0}' -f $after.ShareName) }
        else { Add-Result 'Verifikasi share' 'FAIL' 'Masih belum ter-share'; $script:Failed = $true }

        if (@(Get-NetTCPConnection -LocalPort 445 -State Listen -ErrorAction SilentlyContinue).Count -gt 0) {
            Add-Result 'Port 445 (SMB)' 'OK' 'Listening'
        }
        else { Add-Result 'Port 445 (SMB)' 'FAIL' 'Tidak listening'; $script:Failed = $true }

        if (@(Get-NetTCPConnection -LocalPort 135 -State Listen -ErrorAction SilentlyContinue).Count -gt 0) {
            Add-Result 'Port 135 (RPC)' 'OK' 'Listening'
        }
        else { Add-Result 'Port 135 (RPC)' 'WARN' 'Tidak listening' }
    }
}

try { Invoke-Main }
catch { Add-Result 'Fatal' 'FAIL' $_.Exception.Message; $script:Failed = $true }
finally {
    Save-Backup

    Write-Host ''
    Write-Host '================ RINGKASAN ================' -ForegroundColor Cyan
    $script:Results | Format-Table -AutoSize Step, Status, Detail | Out-String -Width 300 | Write-Host

    if (-not $WhatIfPreference -and -not $script:Failed) {
        Write-Host '=========== CARA CONNECT DARI KLIEN ===========' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'Klien Windows 10 :  client\Win10\02-Connect-Win10.ps1' -ForegroundColor Yellow
        Write-Host ('  .\02-Connect-Win10.ps1 -Server {0} -ShareName {1} -SetDefault -TestPage' -f $env:COMPUTERNAME, $ShareName) -ForegroundColor Gray
        Write-Host ''
        Write-Host 'Klien Windows 11 :  client\Win11\02-Connect-Win11.ps1' -ForegroundColor Yellow
        Write-Host ('  .\02-Connect-Win11.ps1 -Server {0} -ShareName {1} -SetDefault -TestPage' -f $env:COMPUTERNAME, $ShareName) -ForegroundColor Gray
        Write-Host ''
        Write-Host 'Klien Windows 7  :  client\Win7\02-Connect-Win7.cmd' -ForegroundColor Yellow
        Write-Host ('  02-Connect-Win7.cmd {0} {1}' -f $env:COMPUTERNAME, $ShareName) -ForegroundColor Gray
        Write-Host ''
        Write-Host 'UNC:' -ForegroundColor Yellow
        Write-Host ('  {0}' -f $unc) -ForegroundColor White
        Write-Host ''
    }

    Write-Host ('Log    : {0}' -f $transcript) -ForegroundColor DarkGray
    Write-Host ('Backup : {0}' -f $script:BackupPath) -ForegroundColor DarkGray
    Write-Host ('Rollback: ..\..\tools\05-Rollback.ps1 -BackupFile "{0}"' -f $script:BackupPath) -ForegroundColor DarkGray
    Write-Host ''
    try { Stop-Transcript | Out-Null } catch { }
}

if ($script:Failed) { exit 1 } else { exit 0 }
