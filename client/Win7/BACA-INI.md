# KLIEN Windows 7 — BACA INI DULU

Folder ini untuk **PC yang mau mencetak** (bukan yang menempel printer),
OS-nya **Windows 7**.

> Host boleh Windows 7, 10, atau 11 — tidak masalah.
> Yang penting: folder `host\` dijalankan di PC yang menempel printer.

> Klien Windows 10 → pakai `..\Win10\`
> Klien Windows 11 → pakai `..\Win11\`

## Dua mode — pilih sesuai arsitektur

| Windows 7 klien | Mode | File | Keterangan |
|---|---|---|---|
| **64-bit** | `Legacy` | `02-Connect-Win7.ps1` (atau `.cmd`) | printui /in, paling mudah |
| **32-bit** | `LocalPort` | `02-Connect-Win7.ps1` | butuh **driver x86** dari vendor |

**Kenapa 32-bit beda?** Host 64-bit (Win10/11) tidak bisa mengirim driver
32-bit ke klien. Jadi klien 32-bit harus membuat printer lokal sendiri
dengan port `\\HOST\Share` dan driver x86. Ini menghindari error
`0x0000007e`.

## Kalau klien Windows 7 64-bit

```powershell
cd C:\printer-share\client\Win7

# cara paling cepat: batch, tidak perlu PowerShell
02-Connect-Win7.cmd PC-HOST EPSON-L120

# atau lewat PowerShell (lebih banyak opsi)
.\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage
```

## Kalau klien Windows 7 32-bit

1. Download driver dari situs vendor (Epson/Canon/HP/…), pilih versi **32-bit / x86**.
2. Extract ke `C:\Driver\x86\` (atau folder lain).
3. Cari file `.inf` di dalamnya, lalu:

```powershell
cd C:\printer-share\client\Win7
.\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120 -Mode LocalPort -DriverInf "C:\Driver\x86\driver.inf"
```

Kalau tidak yakin nama modelnya, jangan isi `-DriverName` — Windows akan
menampilkan daftar driver dari INF.

## Kalau gagal

| Pesan / kode | Arti | Solusi |
|---|---|---|
| `0x0000011b` | host memblokir RPC lama | di **host**: `-AllowLegacyWin7` |
| `0x00000bc4` | driver tidak ada | di **host**: `-AllowLegacyWin7`, atau pakai LocalPort |
| `0x0000007e` | beda arsitektur | pakai `-Mode LocalPort` + driver x86 |
| Akses ditolak | butuh login ke host | `-SaveCredential` |
| Port 445 tertutup | firewall / profil host | di **host**: profil Private + firewall |

## Opsi lain

```powershell
# lihat printer yang di-share di host (WMI)
.\02-Connect-Win7.ps1 -Server PC-HOST -ListRemote

# hapus lalu pasang ulang
.\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120 -Repair

# lihat rencana tanpa mengubah
.\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120 -WhatIf
```

## Diagnosa lanjutan

```powershell
..\..\tools\03-Test-PrinterShare.ps1 -Server PC-HOST -ShareName EPSON-L120
```
