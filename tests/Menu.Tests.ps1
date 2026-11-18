#Requires -Version 5.1
<#
.SYNOPSIS
    Test untuk Menu.ps1 (logika menu, tanpa menjalankan menunya).
#>

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

# Menu.ps1 sengaja tidak dijalankan saat di-dot-source, jadi aman dimuat di sini.
. (Join-Path $script:RepoRoot 'Menu.ps1')

Describe 'Menu.ps1 - pemuatan' {
    It 'tidak menjalankan menu saat di-dot-source' {
        Assert-NotNull (Get-Command -Name 'Start-Menu' -ErrorAction SilentlyContinue) 'Fungsi Start-Menu tidak terdefinisi.'
    }

    It 'membaca versi dari file VERSION' {
        $expected = (Get-Content -LiteralPath (Join-Path $script:RepoRoot 'VERSION') -TotalCount 1).Trim()
        Assert-Equal $Script:Version $expected
    }

    It 'menyimpan root di folder repositori' {
        Assert-Equal $Script:Root $script:RepoRoot
    }
}

Describe 'Menu.ps1 - deteksi OS' {
    It 'mengenali keluarga OS' {
        Assert-True (@('Win7', 'Win8', 'Win10', 'Win11') -contains $Script:OsFamily) ("OS tidak dikenal: " + $Script:OsFamily)
    }

    It 'menunjuk script host yang ada' {
        $p = Get-HostScript
        Assert-True (Test-Path -LiteralPath $p) ("Script host tidak ada: " + $p)
    }

    It 'menunjuk script klien yang ada' {
        $p = Get-ClientScript
        Assert-True (Test-Path -LiteralPath $p) ("Script klien tidak ada: " + $p)
    }

    It 'memberi label OS yang tidak kosong' {
        Assert-True ((Get-OsLabel).Length -gt 0)
    }
}

Describe 'Menu.ps1 - bahasa' {
    It 'menerjemahkan kunci di kedua bahasa' {
        $before = $Script:Lang
        try {
            $Script:Lang = 'id'
            Assert-Equal (T 'itemExit') 'KELUAR'
            $Script:Lang = 'en'
            Assert-Equal (T 'itemExit') 'EXIT'
        }
        finally {
            $Script:Lang = $before
        }
    }

    It 'memakai Indonesia sebagai fallback' {
        $before = $Script:Lang
        try {
            $Script:Lang = 'xx'
            Assert-Equal (T 'itemExit') 'KELUAR'
        }
        finally {
            $Script:Lang = $before
        }
    }

    It 'mengembalikan nama kunci bila kunci tidak ada' {
        Assert-Equal (T 'kunci.tidak.ada.xyz') 'kunci.tidak.ada.xyz'
    }

    It 'punya daftar kunci yang sama untuk ID dan EN' {
        $idKeys = @($Script:Strings['id'].Keys)
        $enKeys = @($Script:Strings['en'].Keys)
        $missingEn = @($idKeys | Where-Object { -not $Script:Strings['en'].ContainsKey($_) })
        $missingId = @($enKeys | Where-Object { -not $Script:Strings['id'].ContainsKey($_) })
        Assert-Equal $missingEn.Count 0 ('Kunci hilang di EN: ' + ($missingEn -join ', '))
        Assert-Equal $missingId.Count 0 ('Kunci hilang di ID: ' + ($missingId -join ', '))
    }
}

Describe 'Menu.ps1 - format argumen' {
    It 'memformat hashtable sebagai parameter bernama' {
        $s = Format-ToolArgs @{ Server = 'PC-TEST'; Repair = $true; SetDefault = $false }
        Assert-Match $s '-Server "PC-TEST"'
        Assert-Match $s '-Repair'
        Assert-NotMatch $s '-SetDefault'
    }

    It 'memformat array sebagai argumen posisional' {
        $s = Format-ToolArgs @('PC-TEST', 'SHARE-X', '-', '-', 'test', '-')
        Assert-Equal $s 'PC-TEST SHARE-X - - test -'
    }

    It 'mengembalikan teks kosong untuk argumen kosong' {
        Assert-Equal (Format-ToolArgs $null) ''
    }
}

Describe 'Menu.ps1 - printer' {
    It 'Get-LocalPrinterNames mengembalikan daftar tanpa error' {
        $names = @(Get-LocalPrinterNames)
        foreach ($n in $names) { Assert-True ($n.Length -gt 0) }
    }

    It 'Get-SharedPrinters mengembalikan objek dengan properti Name/ShareName' {
        $shared = @(Get-SharedPrinters)
        foreach ($p in $shared) {
            Assert-NotNull $p.Name
            Assert-True ($p.PSObject.Properties.Name -contains 'ShareName')
        }
    }

    It 'Get-ShareStatusText mengembalikan teks' {
        Assert-True ((Get-ShareStatusText).Length -gt 0)
    }

    It 'Test-IsAdmin mengembalikan boolean' {
        Assert-True ((Test-IsAdmin) -is [bool])
    }
}
