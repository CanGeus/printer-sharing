#Requires -Version 5.1
<#
.SYNOPSIS
    Menerapkan fix kompatibilitas agar printer share bisa diakses Windows 7.

.DESCRIPTION
    Menangani dua penyebab kegagalan paling umum:

      1. 0x0000011b  ->  RpcAuthnLevelPrivacyEnabled = 0
         (hardening Print Spooler setelah PrintNightmare memblokir klien lama)

      2. 0x00000bc4 / 0x0000007e  ->  Point and Print policy
         (RestrictDriverInstallationToAdministrators = 0, dll)

    Dengan -AllowGuest, ditambahkan izin guest / blank password.
    Semua perubahan dicatat ke backup JSON untuk 05-Rollback.ps1.

    PERINGATAN: pengaturan di sini MENURUNKAN keamanan host.
    Pakai hanya selama masih ada klien Windows 7 di jaringan.

.EXAMPLE
    .\04-Fix-LegacyCompat.ps1 -AllowLegacyWin7

.EXAMPLE
    .\04-Fix-LegacyCompat.ps1 -AllowLegacyWin7 -AllowGuest

.EXAMPLE
    .\04-Fix-LegacyCompat.ps1 -AllowLegacyWin7 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$BackupPath,
    [switch]$AllowLegacyWin7,
    [switch]$AllowGuest
)

$ErrorActionPreference = 'Stop'

$script:LogDir = Join-Path $env:ProgramData 'PrinterShare\logs'
if (-not (Test-Path -LiteralPath $script:LogDir)) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
}
if (-not $BackupPath) {
    $BackupPath = Join-Path $script:LogDir ('backup-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

if (-not $AllowLegacyWin7 -and -not $AllowGuest) {
    Write-Host ''
    Write-Host 'Tidak ada aksi. Pilih minimal satu:' -ForegroundColor Yellow
    Write-Host '  -AllowLegacyWin7   fix RPC + Point and Print (0x0000011b / 0x00000bc4)' -ForegroundColor Gray
    Write-Host '  -AllowGuest        tambahan izin guest / blank password' -ForegroundColor Gray
    Write-Host ''
    exit 2
}

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Harus dijalankan sebagai Administrator.' -ForegroundColor Red
    exit 1
}

# ----------------------------------------------------------------------------
# Backup
# ----------------------------------------------------------------------------
function Read-Backup {
    if (Test-Path -LiteralPath $BackupPath) {
        try {
            return (Get-Content -LiteralPath $BackupPath -Raw | ConvertFrom-Json)
        }
        catch {
            Write-Host ('[WARN] Backup lama tidak bisa dibaca, dibuat baru: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    return [pscustomobject]@{
        Created         = (Get-Date).ToString('o')
        Computer        = $env:COMPUTERNAME
        NetworkProfiles = @()
        Services        = @()
        FirewallRules   = @()
        Printers        = @()
        Registry        = @()
    }
}

function Save-BackupData {
    param($Data)
    $Data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $BackupPath -Encoding UTF8
}

$backup = Read-Backup
$newEntries = New-Object System.Collections.ArrayList

# ----------------------------------------------------------------------------
# Set registry + catat nilai lama
# ----------------------------------------------------------------------------
function Set-RegValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = 'DWord'
    )

    $existed = $false
    $oldValue = $null
    $oldType = $null

    if (Test-Path -LiteralPath $Path) {
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            $existed = $true
            $oldValue = $item.$Name
            try { $oldType = (Get-Item -LiteralPath $Path).GetValueKind($Name).ToString() } catch { $oldType = $Type }
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($Path, 'Create registry key')) {
            New-Item -Path $Path -Force | Out-Null
        }
    }

    [void]$newEntries.Add([pscustomobject]@{
        Path     = $Path
        Name     = $Name
        Existed  = $existed
        OldValue = $oldValue
        OldType  = $oldType
    })

    if ($PSCmdlet.ShouldProcess(("{0}\{1}" -f $Path, $Name), ("Set {0} = {1}" -f $Name, $Value))) {
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        return $true
    }
    return $false
}

Write-Host ''
Write-Host '=== Fix kompatibilitas printer legacy ===' -ForegroundColor Cyan
Write-Host ''

$changed = 0
$printRegistryTouched = $false

if ($AllowLegacyWin7) {

    Write-Host '[1/2] Mengizinkan RPC otentikasi lama (fix 0x0000011b)' -ForegroundColor Yellow
    if (Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' `
                     -Name 'RpcAuthnLevelPrivacyEnabled' -Value 0 -Type DWord) {
        Write-Host '      RpcAuthnLevelPrivacyEnabled = 0' -ForegroundColor Green
        $changed++
    }
    $printRegistryTouched = $true

    Write-Host '[2/2] Point and Print policy (fix 0x00000bc4 / 0x0000007e)' -ForegroundColor Yellow
    $pnp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
    if (Set-RegValue -Path $pnp -Name 'RestrictDriverInstallationToAdministrators' -Value 0 -Type DWord) {
        Write-Host '      RestrictDriverInstallationToAdministrators = 0' -ForegroundColor Green; $changed++
    }
    if (Set-RegValue -Path $pnp -Name 'NoWarningNoElevationOnInstall' -Value 1 -Type DWord) {
        Write-Host '      NoWarningNoElevationOnInstall = 1' -ForegroundColor Green; $changed++
    }
    if (Set-RegValue -Path $pnp -Name 'UpdatePromptSettings' -Value 2 -Type DWord) {
        Write-Host '      UpdatePromptSettings = 2' -ForegroundColor Green; $changed++
    }
    $printRegistryTouched = $true
}

if ($AllowGuest) {
    Write-Host '[+]  Izin guest / blank password' -ForegroundColor Yellow
    if (Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
                     -Name 'LimitBlankPasswordUse' -Value 0 -Type DWord) {
        Write-Host '      LimitBlankPasswordUse = 0' -ForegroundColor Green; $changed++
    }
    if (Set-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' `
                     -Name 'AllowInsecureGuestAuth' -Value 1 -Type DWord) {
        Write-Host '      AllowInsecureGuestAuth = 1' -ForegroundColor Green; $changed++
    }
    if (Set-RegValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation' `
                     -Name 'AllowInsecureGuestAuth' -Value 1 -Type DWord) {
        Write-Host '      Policy AllowInsecureGuestAuth = 1' -ForegroundColor Green; $changed++
    }
    Write-Host ''
    Write-Host '      CATATAN: Windows 11 24H2+ mengabaikan AllowInsecureGuestAuth.' -ForegroundColor Yellow
    Write-Host '      Untuk 24H2+, pakai akun lokal berpassword (lihat README).' -ForegroundColor Yellow
}

# ----------------------------------------------------------------------------
# Simpan backup
# ----------------------------------------------------------------------------
$backup.Registry = @($backup.Registry) + @($newEntries.ToArray())
Save-BackupData -Data $backup

# ----------------------------------------------------------------------------
# Restart spooler
# ----------------------------------------------------------------------------
if ($printRegistryTouched) {
    if ($PSCmdlet.ShouldProcess('Spooler', 'Restart service')) {
        Restart-Service -Name Spooler -Force
        Write-Host ''
        Write-Host 'Spooler direstart agar perubahan RPC berlaku.' -ForegroundColor Green
    }
}

Write-Host ''
Write-Host ('Selesai. {0} nilai registry diproses.' -f $changed) -ForegroundColor Cyan
Write-Host ('Backup: {0}' -f $BackupPath) -ForegroundColor DarkGray
Write-Host ''

exit 0
