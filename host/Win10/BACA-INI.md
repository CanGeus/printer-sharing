# HOST Windows 10 — BACA INI DULU

Folder ini untuk **PC yang menempel printer (USB)** dan OS-nya **Windows 10**.

> Kalau PC host-nya Windows 11 → pakai `..\Win11\`
> Kalau PC host-nya Windows 7  → pakai `..\Win7\`

## 3 langkah

```powershell
# 1. jalankan PowerShell sebagai Administrator, masuk ke folder ini
cd C:\Users\admin\printer-share\host\Win10

# 2. lihat nama printer
.\01-Sharing-Win10.ps1 -ListPrinters

# 3. coba dulu (tidak mengubah apa pun), lalu jalankan sungguhan
.\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7 -WhatIf
.\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7
```

`-AllowLegacyWin7` wajib kalau ada klien **Windows 7**. Kalau semua klien
Windows 10/11, boleh dihilangkan (lebih aman).

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
