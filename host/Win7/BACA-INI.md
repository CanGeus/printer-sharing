# HOST Windows 7 — BACA INI DULU

Folder ini untuk **PC yang menempel printer (USB)** dan OS-nya **Windows 7**.

> Kalau PC host-nya Windows 10 → pakai `..\Win10\`
> Kalau PC host-nya Windows 11 → pakai `..\Win11\`

Script ini kompatibel **PowerShell 2.0** (bawaan Windows 7).

## 3 langkah

```powershell
# 1. jalankan PowerShell sebagai Administrator
#    Start -> ketik "powershell" -> klik kanan -> Run as administrator
cd C:\printer-share\host\Win7

# 2. lihat nama printer
.\01-Sharing-Win7.ps1 -ListPrinters

# 3. coba dulu, lalu jalankan sungguhan
.\01-Sharing-Win7.ps1 -PrinterName "EPSON L120 Series" -WhatIf
.\01-Sharing-Win7.ps1 -PrinterName "EPSON L120 Series"
```

Kalau PowerShell menolak menjalankan script, buka dulu:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process
```

## Catatan penting

1. **Windows 7 tidak punya `Set-Printer` / `Get-Printer`.**
   Script ini memakai `Get-WmiObject`, `prncnfg.vbs`, `printui`, dan
   `net share` sebagai gantinya. Tidak perlu install apa pun.

2. **SMB2 harus aktif.** Windows 7 sudah mendukung SMB2 secara default.
   Kalau di sistem ini dimatikan, tambahkan `-EnableSMB2`.

3. **Klien Windows 10/11 tidak butuh SMB1.** Jadi SMB1 tetap mati.

4. **Jangan pakai host Windows 7 untuk klien Windows 11 24H2** bila
   memungkinkan. Lebih aman host-nya Windows 10/11. Kalau tetap harus,
   gunakan akun berpassword di host dan `-SaveCredential` di klien.

5. **Host Windows 7 32-bit tidak bisa melayani klien Windows 7 64-bit
   dengan printui.** Klien 64-bit tetap bisa pakai driver Type 3 dari
   vendor yang tersedia dalam versi x64, atau pakai LocalPort.

## Yang diubah

- Network location → Private (lewat registry `NetworkList`)
- Firewall: File and Printer Sharing + Network Discovery (via COM,
  jadi tetap jalan di Windows berbahasa Indonesia)
- Layanan: Spooler, LanmanServer, FDResPub, SSDPSRV, upnphost
- SMB2 dipastikan aktif
- Printer di-share + diverifikasi

Semua perubahan dicatat ke:

```
C:\ProgramData\PrinterShare\logs\Win7-backup-YYYYMMDD-HHMMSS.txt
```

## Kalau perlu dikembalikan

```powershell
..\..\tools\05-Rollback-Win7.ps1
```

## Setelah selesai

Script menampilkan UNC, misalnya `\\PC-HOST\EPSON-L120`.
Catat itu, lalu lanjut ke folder `client\` sesuai OS PC yang mau mencetak.

- Klien Win10 → `..\..\client\Win10\`
- Klien Win11 → `..\..\client\Win11\`
- Klien Win7  → `..\..\client\Win7\`
