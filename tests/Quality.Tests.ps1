#Requires -Version 5.1
<#
.SYNOPSIS
    Test integrasi untuk pemeriksa kualitas tools\dev\Test-Scripts.ps1.
#>

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

function Invoke-Checker {
    param([string]$RepoRoot)

    $checker = Join-Path $RepoRoot 'tools\dev\Test-Scripts.ps1'
    $exe = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($exe) {
        & $exe.Source -NoProfile -ExecutionPolicy Bypass -File $checker *> $null
    }
    else {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $checker *> $null
    }
    return $LASTEXITCODE
}

Describe 'Pemeriksa kualitas (Test-Scripts.ps1)' {
    It 'lulus pada repositori yang bersih' {
        Assert-Equal (Invoke-Checker $script:RepoRoot) 0
    }

    It 'gagal saat menemukan kode yang tidak kompatibel PS 2.0' {
        $badDir = Join-Path $script:RepoRoot 'tests\_tmp_negative'
        $badFile = Join-Path $badDir 'Bad-Ps2.ps1'
        New-Item -ItemType Directory -Path $badDir -Force | Out-Null
        Set-Content -LiteralPath $badFile -Encoding ASCII -Value @(
            '#Requires -Version 2.0'
            '$here = $PSScriptRoot'
            '$list = [ordered]@{ a = 1 }'
        )
        try {
            $code = Invoke-Checker $script:RepoRoot
            Assert-True ($code -ne 0) 'Pemeriksa seharusnya gagal pada file yang tidak kompatibel.'
        }
        finally {
            Remove-Item -LiteralPath $badDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
