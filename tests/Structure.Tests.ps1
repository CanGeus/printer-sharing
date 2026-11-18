#Requires -Version 5.1

<#
.SYNOPSIS
    Memeriksa kelengkapan struktur repositori.

.DESCRIPTION
    Lihat catatan versi Pester di Menu.Tests.ps1.
#>

# $RepoRoot dipakai di dalam blok It (Pester); analyzer tidak melihat pemakaian itu.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variabel dipakai di dalam blok It (Pester).')]
param()

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

if ((Get-PesterMajorVersion) -ge 5) {
    BeforeAll {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }
}

Describe 'Struktur repositori' {
    $fileCases = @()
    foreach ($rel in (Get-RequiredFiles)) { $fileCases += @{ rel = $rel } }

    It 'file ada: <rel>' -TestCases $fileCases {
        param($rel)
        $full = Join-Path $RepoRoot $rel
        Assert-True (Test-Path -LiteralPath $full -PathType Leaf) ('File tidak ditemukan: ' + $full)
    }

    It 'VERSION berisi versi semantik' {
        $v = (Get-Content -LiteralPath (Join-Path $RepoRoot 'VERSION') -TotalCount 1).Trim()
        Assert-Match $v '^[0-9]+\.[0-9]+\.[0-9]+$'
    }

    It 'Menu.cmd memanggil Menu.ps1' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot 'Menu.cmd') -Raw
        Assert-Match $c 'Menu\.ps1'
    }

    It 'Menu.cmd meminta hak Administrator (RunAs)' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot 'Menu.cmd') -Raw
        Assert-Match $c 'RunAs'
    }

    It 'CI menjalankan pemeriksa script' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot '.github\workflows\ci.yml') -Raw
        Assert-Match $c 'Test-Scripts\.ps1'
    }

    It 'CI menjalankan test Pester' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot '.github\workflows\ci.yml') -Raw
        Assert-Match $c 'Run-Tests\.ps1'
    }

    It 'README (ID) menyebut Menu.cmd' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot 'README.md') -Raw
        Assert-Match $c 'Menu\.cmd'
    }

    It 'README (EN) menyebut Menu.cmd' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot 'README.en.md') -Raw
        Assert-Match $c 'Menu\.cmd'
    }

    It 'batch Win7 tidak menerima password lewat command line' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot 'client\Win7\02-Connect-Win7.cmd') -Raw
        Assert-NotMatch $c '%PPASS%'
        Assert-Match $c '/user:%PUSER% \*'
    }

    It 'klien Win7 .ps1 menyimpan kredensial tanpa cmdkey /pass:' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot 'client\Win7\02-Connect-Win7.ps1') -Raw
        Assert-NotMatch $c 'cmdkey\.exe'
        Assert-Match $c 'CredWrite'
    }

    It 'menu mengoper user (bukan password) ke batch Win7' {
        $c = Get-Content -LiteralPath (Join-Path $RepoRoot 'Menu.ps1') -Raw
        Assert-Match $c '02-Connect-Win7\.cmd'
        Assert-Match $c '\$server, \$share, \$user'
    }
}
