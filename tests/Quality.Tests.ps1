#Requires -Version 5.1

<#
.SYNOPSIS
    Test integrasi untuk pemeriksa kualitas tools\dev\Test-Scripts.ps1.

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

Describe 'Pemeriksa kualitas (Test-Scripts.ps1)' {
    It 'lulus pada repositori yang bersih' {
        Assert-Equal (Invoke-QualityChecker -RepoRoot $RepoRoot) 0
    }

    It 'gagal saat menemukan kode yang tidak kompatibel PS 2.0' {
        $badDir = Join-Path $RepoRoot 'tests\_tmp_negative'
        $badFile = Join-Path $badDir 'Bad-Ps2.ps1'
        New-Item -ItemType Directory -Path $badDir -Force | Out-Null
        Set-Content -LiteralPath $badFile -Encoding ASCII -Value @(
            '#Requires -Version 2.0'
            '$here = $PSScriptRoot'
            '$list = [ordered]@{ a = 1 }'
        )
        try {
            $code = Invoke-QualityChecker -RepoRoot $RepoRoot
            Assert-True ($code -ne 0) 'Pemeriksa seharusnya gagal pada file yang tidak kompatibel.'
        }
        finally {
            Remove-Item -LiteralPath $badDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
