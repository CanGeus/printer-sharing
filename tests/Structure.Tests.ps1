#Requires -Version 5.1
<#
.SYNOPSIS
    Memeriksa kelengkapan struktur repositori.
#>

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

$script:RequiredFiles = @(
    'Menu.cmd'
    'Menu.ps1'
    'README.md'
    'README.en.md'
    'LICENSE'
    'VERSION'
    'CHANGELOG.md'
    '.gitignore'
    '.editorconfig'
    'PSScriptAnalyzerSettings.psd1'
    'tools\dev\Test-Scripts.ps1'
    'tools\03-Test-PrinterShare.ps1'
    'tools\04-Fix-LegacyCompat.ps1'
    'tools\05-Rollback.ps1'
    'tools\05-Rollback-Win7.ps1'
    'host\Win7\01-Sharing-Win7.ps1'
    'host\Win10\01-Sharing-Win10.ps1'
    'host\Win11\01-Sharing-Win11.ps1'
    'client\Win7\02-Connect-Win7.cmd'
    'client\Win7\02-Connect-Win7.ps1'
    'client\Win10\02-Connect-Win10.ps1'
    'client\Win11\02-Connect-Win11.ps1'
    '.github\workflows\ci.yml'
)

Describe 'Struktur repositori' {
    foreach ($rel in $script:RequiredFiles) {
        $full = Join-Path $script:RepoRoot $rel
        It ('file ada: ' + $rel) {
            Assert-True (Test-Path -LiteralPath $full -PathType Leaf) ('File tidak ditemukan: ' + $full)
        }
    }

    It 'VERSION berisi versi semantik' {
        $v = (Get-Content -LiteralPath (Join-Path $script:RepoRoot 'VERSION') -TotalCount 1).Trim()
        Assert-Match $v '^[0-9]+\.[0-9]+\.[0-9]+$'
    }

    It 'Menu.cmd memanggil Menu.ps1' {
        $c = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'Menu.cmd') -Raw
        Assert-Match $c 'Menu\.ps1'
    }

    It 'Menu.cmd meminta hak Administrator (RunAs)' {
        $c = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'Menu.cmd') -Raw
        Assert-Match $c 'RunAs'
    }

    It 'CI menjalankan pemeriksa script' {
        $c = Get-Content -LiteralPath (Join-Path $script:RepoRoot '.github\workflows\ci.yml') -Raw
        Assert-Match $c 'Test-Scripts\.ps1'
    }

    It 'CI menjalankan test Pester' {
        $c = Get-Content -LiteralPath (Join-Path $script:RepoRoot '.github\workflows\ci.yml') -Raw
        Assert-Match $c 'Run-Tests\.ps1'
    }

    It 'README (ID) menyebut Menu.cmd' {
        $c = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'README.md') -Raw
        Assert-Match $c 'Menu\.cmd'
    }

    It 'README (EN) menyebut Menu.cmd' {
        $c = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'README.en.md') -Raw
        Assert-Match $c 'Menu\.cmd'
    }
}
