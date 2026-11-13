# HOST Windows 11 — BACA INI DULU

Folder ini untuk **PC yang menempel printer (USB)** dan OS-nya **Windows 11**.

> Kalau PC host-nya Windows 10 → pakai `..\Win10\`
> Kalau PC host-nya Windows 7  → pakai `..\Win7\`

## 3 langkah

```powershell
# 1. jalankan PowerShell sebagai Administrator, masuk ke folder ini
cd C:\Users\admin\printer-share\host\Win11

# 2. lihat nama printer
.\01-Sharing-Win11.ps1 -ListPrinters

# 3. coba dulu (tidak mengubah apa pun), lalu jalankan sungguhan
.\01-Sharing-Win11.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7 -WhatIf
.\01-Sharing-Win11.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7
```

`-AllowLegacyWin7` wajib kalau ada klien **Windows 7**. Kalau semua klien
Windows 10/11, boleh dihilangkan (lebih aman).

## Khusus Windows 11

1. **Windows Protected Print Mode harus MATI.**
   Settings → Bluetooth & devices → Printers & scanners →
   Printers & scanners settings → matikan *Windows protected print*.
   Kalau aktif, sharing printer legacy tidak akan jalan. Script akan
   memberi peringatan kalau mendeteksinya.

2. **24H2 (build 26100+) lebih ketat.**
   Driver v3 lama dan akses guest tanpa password dibatasi. Untuk klien
   Win7 di 24H2, host sebaiknya memakai akun lokal berpassword dan klien
   connect dengan `-SaveCredential`.

3. **Driver Type 4** (biasanya driver bawaan Windows / IPP) tidak bisa
   dipakai klien Windows 7. Script host akan menolak bila dipaksa.
   Pasang driver Type 3 dari vendor dulu (mis. Epson L120 driver resmi).

## Yang diubah

- Profil jaringan → Private
- Firewall: File and Printer Sharing + Network Discovery
- Layanan: Spooler, LanmanServer, FDResPub, fdPHost, SSDPSRV, upnphost
- SMB2 dipastikan aktif (SMB1 tetap mati)
- Printer di-share + diverifikasi

## Kalau perlu dikembalikan

```powershell
..\..\tools\05-Rollback.ps1
```

## Setelah selesai

Script menampilkan UNC, misalnya `\\PC-HOST\EPSON-L120`.
Catat itu, lalu lanjut ke folder `client\` sesuai OS PC yang mau mencetak.

- Klien Win10 → `..\..\client\Win10\`
- Klien Win11 → `..\..\client\Win11\`
- Klien Win7  → `..\..\client\Win7\`
