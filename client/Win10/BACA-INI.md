# KLIEN Windows 10 — BACA INI DULU

Folder ini untuk **PC yang mau mencetak** (bukan yang menempel printer),
OS-nya **Windows 10**.

> Host boleh Windows 7, 10, atau 11 — tidak masalah.
> Yang penting: folder `host\` dijalankan di PC yang menempel printer.

> Klien Windows 11 → pakai `..\Win11\`
> Klien Windows 7  → pakai `..\Win7\`

## Yang perlu disiapkan

Dari script host, catat **UNC**-nya. Contoh:

```
\\PC-HOST\EPSON-L120
```

Artinya `-Server` = `PC-HOST`, `-ShareName` = `EPSON-L120`.

## 2 langkah

```powershell
# 1. masuk ke folder ini
cd C:\Users\admin\printer-share\client\Win10

# 2. connect (tambahkan -WhatIf dulu kalau mau lihat rencananya)
.\02-Connect-Win10.ps1 -Server PC-HOST -ShareName EPSON-L120 -WhatIf
.\02-Connect-Win10.ps1 -Server PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage
```

## Kalau gagal

| Pesan / kode | Arti | Solusi |
|---|---|---|
| `0x0000011b` | host memblokir RPC lama | di **host**: jalankan `01-...` dengan `-AllowLegacyWin7` |
| `0x00000bc4` | driver tidak ditemukan | di **host**: `-AllowLegacyWin7`, atau pakai mode `-Mode Legacy` |
| `0x00000709` | gagal set default | restart Spooler di host dan klien, lalu ulangi |
| Akses ditolak | butuh login ke host | `-SaveCredential` (akan minta user/password host) |
| Port 445 tertutup | firewall / profil jaringan host | di **host**: profil Private + firewall aktif |

Opsi lain:

```powershell
# lihat printer yang di-share di host
.\02-Connect-Win10.ps1 -Server PC-HOST -ListRemote

# hapus lalu pasang ulang
.\02-Connect-Win10.ps1 -Server PC-HOST -ShareName EPSON-L120 -Repair

# simpan kredensial + fix RPC di klien (butuh Admin)
.\02-Connect-Win10.ps1 -Server PC-HOST -ShareName EPSON-L120 -SaveCredential -ApplyCompatFix
```

## Diagnosa lanjutan

```powershell
..\..\tools\03-Test-PrinterShare.ps1 -Server PC-HOST -ShareName EPSON-L120
```
