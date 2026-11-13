# Printer Share Toolkit — Windows 7 / 10 / 11

Perkakas untuk membagikan printer **USB** yang menempel di satu PC (host)
supaya bisa dipakai PC lain (klien) di jaringan yang sama, lewat
**SMB2** (bukan SMB1).

Tujuan: menghindari error berulang saat sharing printer — `0x0000011b`,
`0x00000bc4`, `0x00000709`, `0x0000007e`, dan printer yang "hilang".

---

## Pilih folder sesuai OS

Setiap OS punya script sendiri supaya tidak tertukar.

### Host (PC yang menempel printer)

| OS host | Folder | Script |
|---|---|---|
| Windows 7 | `host\Win7\` | `01-Sharing-Win7.ps1` |
| Windows 10 | `host\Win10\` | `01-Sharing-Win10.ps1` |
| Windows 11 | `host\Win11\` | `01-Sharing-Win11.ps1` |

### Klien (PC yang mau mencetak)

| OS klien | Folder | Script |
|---|---|---|
| Windows 7 64-bit | `client\Win7\` | `02-Connect-Win7.cmd` atau `02-Connect-Win7.ps1` |
| Windows 7 32-bit | `client\Win7\` | `02-Connect-Win7.ps1 -Mode LocalPort` |
| Windows 10 | `client\Win10\` | `02-Connect-Win10.ps1` |
| Windows 11 | `client\Win11\` | `02-Connect-Win11.ps1` |

Setiap folder punya `BACA-INI.md` berisi langkah cepat + solusi error.

---

## Matriks lengkap host × klien

| Host ↓ / Klien → | Win7 64-bit | Win7 32-bit | Win10 | Win11 |
|---|---|---|---|---|
| **Win7** | `client\Win7\02-Connect-Win7.cmd` | `client\Win7\02-Connect-Win7.ps1 -Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |
| **Win10** | `client\Win7\02-Connect-Win7.cmd` | `client\Win7\02-Connect-Win7.ps1 -Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |
| **Win11** | `client\Win7\02-Connect-Win7.cmd` | `client\Win7\02-Connect-Win7.ps1 -Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |

Catatan:

- Klien selalu memakai script **milik OS klien**, bukan OS host.
- Baris **Win7 32-bit** selalu `-Mode LocalPort` + driver x86 dari vendor.
- Host **Win11 24H2** ke klien **Win7** adalah kombinasi paling rawan;
  pakai akun lokal berpassword di host + `-SaveCredential` di klien.

---

## Langkah 1 — di PC host

Jalankan **PowerShell sebagai Administrator**, lalu:

```powershell
cd C:\Users\admin\printer-share\host\Win10      # atau Win11 / Win7

.\01-Sharing-Win10.ps1 -ListPrinters
.\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7 -WhatIf
.\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7
```

Ganti `Win10` sesuai OS host. Contoh untuk Win7:

```powershell
cd C:\printer-share\host\Win7
.\01-Sharing-Win7.ps1 -PrinterName "EPSON L120 Series"
```

Script akan menampilkan **UNC**, misalnya:

```
\\PC-HOST\EPSON-L120
```

`-AllowLegacyWin7` hanya perlu bila ada klien **Windows 7**. Tanpa klien
Win7, hilangkan supaya keamanan tetap tinggi. `-AllowGuest` lebih rendah
lagi keamanannya dan hanya dipakai bila benar-benar perlu.

### Yang diubah oleh script host

1. Profil jaringan → **Private**
2. Firewall: **File and Printer Sharing** + **Network Discovery**
3. Layanan: `Spooler`, `LanmanServer`, `FDResPub`, `fdPHost`, `SSDPSRV`, `upnphost`
4. SMB2 dipastikan aktif (**SMB1 tetap mati**)
5. (opsional) fix kompatibilitas Win7
6. Share printer + permission
7. Verifikasi (share status, port 445, port 135)

Semua perubahan dicatat untuk rollback di
`C:\ProgramData\PrinterShare\logs\`.

---

## Langkah 2 — di PC klien

Jalankan script sesuai OS klien.

### Klien Windows 10

```powershell
cd C:\Users\admin\printer-share\client\Win10
.\02-Connect-Win10.ps1 -Server PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage
```

### Klien Windows 11

```powershell
cd C:\Users\admin\printer-share\client\Win11
.\02-Connect-Win11.ps1 -Server PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage
```

### Klien Windows 7 64-bit

```bat
cd C:\printer-share\client\Win7
02-Connect-Win7.cmd PC-HOST EPSON-L120
```

atau dengan PowerShell:

```powershell
cd C:\printer-share\client\Win7
.\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage
```

### Klien Windows 7 32-bit

Butuh driver **32-bit (x86)** dari vendor:

```powershell
cd C:\printer-share\client\Win7
.\02-Connect-Win7.ps1 -Server PC-HOST -ShareName EPSON-L120 -Mode LocalPort -DriverInf "C:\Driver\x86\driver.inf"
```

---

## Daftar isi folder

```
printer-share\
├─ README.md                     ← file ini
├─ host\
│  ├─ Win7\  01-Sharing-Win7.ps1    BACA-INI.md
│  ├─ Win10\ 01-Sharing-Win10.ps1   BACA-INI.md
│  └─ Win11\ 01-Sharing-Win11.ps1   BACA-INI.md
├─ client\
│  ├─ Win7\  02-Connect-Win7.ps1 / .cmd   BACA-INI.md
│  ├─ Win10\ 02-Connect-Win10.ps1         BACA-INI.md
│  └─ Win11\ 02-Connect-Win11.ps1         BACA-INI.md
├─ tools\
│  ├─ 03-Test-PrinterShare.ps1   diagnosa (read-only, PS 2.0-compatible)
│  ├─ 04-Fix-LegacyCompat.ps1    fix registry Win10/11
│  ├─ 05-Rollback.ps1            rollback host Win10/11 (JSON)
│  └─ 05-Rollback-Win7.ps1       rollback host Win7 (journal teks)
└─ _arsip\                       script lama (tidak dipakai)
```

---

## Diagnosa dan rollback

```powershell
# cek dari mana saja (read-only)
C:\Users\admin\printer-share\tools\03-Test-PrinterShare.ps1 -Server PC-HOST -ShareName EPSON-L120

# kembalikan perubahan host Win10/11
C:\Users\admin\printer-share\tools\05-Rollback.ps1

# kembalikan perubahan host Win7
C:\Users\admin\printer-share\tools\05-Rollback-Win7.ps1
```

---

## Tabel error umum

| Kode / pesan | Arti | Solusi |
|---|---|---|
| `0x0000011b` | host menolak RPC lama | jalankan host `01-...` dengan `-AllowLegacyWin7` |
| `0x00000bc4` | driver klien tidak ditemukan | host: `-AllowLegacyWin7`; atau klien: `-Mode Legacy` |
| `0x00000709` | gagal set printer default | restart Spooler di host dan klien |
| `0x0000007e` | beda arsitektur (32 vs 64-bit) | klien 32-bit: `-Mode LocalPort` + driver x86 |
| Akses ditolak | host butuh login | `-SaveCredential` di klien |
| Port 445 tertutup | firewall / profil host | host: profil Private + firewall aktif |
| Printer hilang setelah update | driver/rpc berubah | klien: `-Repair` |
| Win11 24H2 tidak bisa share | guest diblokir | akun berpassword + `-SaveCredential` |
| Win11 tidak bisa share sama sekali | Windows Protected Print aktif | matikan di Settings → Printers |

---

## Prinsip keamanan

- **SMB1 tidak dipakai.** Windows 7 sudah mendukung SMB2.
- Penurunan keamanan (`-AllowLegacyWin7`, `-AllowGuest`) **opt-in per
  switch**, tidak pernah default.
- Klien **Win7 32-bit** tidak memaksa host mengirim driver 32-bit; klien
  memakai driver lokal sendiri.
- Setiap perubahan dicatat dan bisa dibalik.

---

## Catatan uji

Script sudah di-parse-check dengan PowerShell 5.1. Pengujian penuh
(Administrator) dilakukan di PC host masing-masing OS. Baris perintah
`-ListPrinters`, `-WhatIf`, `-ListRemote`, dan mode non-admin sudah
diuji di mesin Windows 10 build 19045.
