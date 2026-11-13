# KLIEN Windows 11 — BACA INI DULU

Folder ini untuk **PC yang mau mencetak** (bukan yang menempel printer),
OS-nya **Windows 11**.

> Host boleh Windows 7, 10, atau 11 — tidak masalah.
> Yang penting: folder `host\` dijalankan di PC yang menempel printer.

> Klien Windows 10 → pakai `..\Win10\`
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
cd C:\Users\admin\printer-share\client\Win11

# 2. connect (tambahkan -WhatIf dulu kalau mau lihat rencananya)
.\02-Connect-Win11.ps1 -Server PC-HOST -ShareName EPSON-L120 -WhatIf
.\02-Connect-Win11.ps1 -Server PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage
```

## Khusus Windows 11

1. **24H2 (build 26100+) mengabaikan akses guest.**
   Host yang share-nya tanpa password tidak bisa diakses. Buat akun lokal
   berpassword di host, lalu di sini pakai `-SaveCredential`.

2. **Windows Protected Print Mode harus mati** kalau printer memakai
   driver lama (non-IPP). Settings → Bluetooth & devices → Printers &
   scanners → Printers & scanners settings.

3. **Driver printer yang di-share harus punya versi x64** agar bisa
   dipasang otomatis. Kalau tidak ada, pakai `-Mode Legacy`.

## Kalau gagal

```powershell
# simpan kredensial host (disarankan di Win11 24H2)
.\02-Connect-Win11.ps1 -Server PC-HOST -ShareName EPSON-L120 -SaveCredential

# lihat printer yang di-share di host
.\02-Connect-Win11.ps1 -Server PC-HOST -ListRemote

# hapus lalu pasang ulang
.\02-Connect-Win11.ps1 -Server PC-HOST -ShareName EPSON-L120 -Repair

# mode pemasangan lama (printui) bila Add-Printer gagal
.\02-Connect-Win11.ps1 -Server PC-HOST -ShareName EPSON-L120 -Mode Legacy
```

Penyebab umum:

| Pesan / kode | Arti | Solusi |
|---|---|---|
| Akses ditolak | guest diblokir (24H2) | akun berpassword di host + `-SaveCredential` |
| `0x0000011b` | RPC lama diblokir host | di **host**: `-AllowLegacyWin7` |
| `0x00000bc4` | driver tidak ditemukan | `-Mode Legacy`, atau driver Type 3 di host |
| Port 445 tertutup | firewall / profil host | di **host**: profil Private + firewall |

## Diagnosa lanjutan

```powershell
..\..\tools\03-Test-PrinterShare.ps1 -Server PC-HOST -ShareName EPSON-L120
```
