# 🖨️ Windows Printer Share Toolkit (Win 7 / 10 / 11)

<p align="center">
  <a href="README.md"><b>Bahasa Indonesia</b></a> •
  <a href="README.en.md"><b>English</b></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OS-Windows%207%20%7C%2010%20%7C%2011-blue?logo=windows" alt="Supported OS" />
  <img src="https://img.shields.io/badge/PowerShell-2.0%20%7C%205.1+-blue?logo=powershell" alt="PowerShell Version" />
  <img src="https://img.shields.io/badge/Protocol-SMB2%20(No%20SMB1)-brightgreen" alt="Protocol SMB2" />
  <img src="https://img.shields.io/badge/Architecture-x86%20%7C%20x64-orange" alt="Architecture" />
  <img src="https://img.shields.io/badge/version-1.0.0-blue" alt="Version" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License MIT" />
</p>

Perkakas otomasi PowerShell dan Batch untuk membagikan printer **USB** yang terhubung di satu PC (Host) agar dapat digunakan oleh PC lain (Klien) di jaringan lokal yang sama secara stabil dan aman melalui **SMB2 (tanpa SMB1)**.

Dibuat khusus untuk mengatasi error printer sharing Windows yang sering muncul akibat pembaruan keamanan (*PrintNightmare*, RPC hardening, dan pembatasan Windows 11 24H2), seperti:
- `0x0000011b` (*RPC authentication level privacy*)
- `0x00000bc4` (*Printer driver was not found / Point and Print policy*)
- `0x00000709` (*Cannot set default printer*)
- `0x0000007e` (*Architecture mismatch: 32-bit x86 vs 64-bit x64*)
- `0x00000005` (*Access Denied / Guest restriction*)
- Printer network yang tiba-tiba "hilang" atau offline setelah update Windows.

---

## 📑 Daftar Isi

- [Fitur Utama](#-fitur-utama)
- [Matriks Kompatibilitas Host × Klien](#-matriks-kompatibilitas-host--klien)
- [Struktur Direktori](#-struktur-direktori)
- [Persiapan Awal](#-persiapan-awal)
- [Cara Cepat (Menu Interaktif)](#-cara-cepat-menu-interaktif)
- [Panduan Penggunaan](#-panduan-penggunaan)
  - [Langkah 1: Setup di PC Host](#langkah-1--setup-di-pc-host)
  - [Langkah 2: Sambungkan dari PC Klien](#langkah-2--sambungkan-dari-pc-klien)
- [Diagnosa & Pemeriksaan](#-diagnosa--pemeriksaan)
- [Rollback (Kembalikan Pengaturan)](#-rollback-kembalikan-pengaturan)
- [Tabel Solusi Error Umum](#-tabel-solusi-error-umum)
- [Prinsip Keamanan](#-prinsip-keamanan)
- [Pengembangan & Pengujian](#-pengembangan--pengujian)

---

## 🚀 Fitur Utama

- **Aman & Modern**: Hanya menggunakan protokol **SMB2/SMB3**. Protokol usang dan rentan **SMB1 tetap dinonaktifkan**.
- **Lintas Versi Windows**: Menghubungkan berbagai kombinasi Windows 7 (32-bit / 64-bit), Windows 10, dan Windows 11 (termasuk build 24H2).
- **Otomasi Konfigurasi Host**: Menyetel profil jaringan ke *Private*, firewall, dependensi layanan discovery (*Spooler*, *LanmanServer*, *FDResPub*, *upnphost*), dan permission printer.
- **Penanganan Khusus Arsitektur Berbeda**: Menyediakan solusi `-Mode LocalPort` agar klien Windows 7 32-bit dapat mencetak ke Host 64-bit tanpa konflik driver.
- **Aman untuk Diuji (*Dry-Run*)**: Mendukung parameter `-WhatIf` untuk simulasi sebelum konfigurasi diterapkan.
- **Rollback Otomatis**: Setiap perubahan dicatat ke dalam jurnal backup JSON / teks sehingga sistem dapat dikembalikan ke keadaan awal kapan saja.

---

## 🧭 Matriks Kompatibilitas Host × Klien

Gunakan script klien yang **sesuai dengan OS Klien** (bukan OS Host):

| Host (Tempat Printer Tercolok) ↓ / Klien → | Klien Win 7 (64-bit) | Klien Win 7 (32-bit) | Klien Win 10 | Klien Win 11 |
|---|---|---|---|---|
| **Host Windows 7** | `client\Win7\02-Connect-Win7.cmd`<br>atau `.ps1` | `client\Win7\02-Connect-Win7.ps1`<br>`-Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |
| **Host Windows 10** | `client\Win7\02-Connect-Win7.cmd`<br>atau `.ps1` | `client\Win7\02-Connect-Win7.ps1`<br>`-Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |
| **Host Windows 11** *(termasuk 24H2)* | `client\Win7\02-Connect-Win7.cmd`<br>atau `.ps1` | `client\Win7\02-Connect-Win7.ps1`<br>`-Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |

> [!NOTE]
> - **Klien Windows 7 32-bit**: Wajib menggunakan `-Mode LocalPort` bersama file driver 32-bit (`.inf`) resmi dari vendor.
> - **Host Windows 11 (build 24H2+)**: Microsoft menonaktifkan akun guest tanpa password secara default. Pastikan Host memiliki akun lokal berpassword dan Klien menghubungkan dengan `-SaveCredential`.
> - **Driver Type 4**: Windows 11 terkadang memakai driver default *Type 4 (IPP)* yang tidak dapat dishare ke Windows 7. Pasang driver resmi *Type 3* dari vendor printer.

---

## 📂 Struktur Direktori

```text
printer-share-toolkit/
├── Menu.cmd                      # Launcher menu interaktif (klik dua kali, auto-Administrator)
├── Menu.ps1                      # Logika menu (kompatibel PowerShell 2.0+)
├── host/                         # Script yang dijalankan di PC yang tercolok printer (USB)
│   ├── Win7/
│   │   ├── 01-Sharing-Win7.ps1   # PowerShell 2.0 compatible
│   │   └── BACA-INI.md
│   ├── Win10/
│   │   ├── 01-Sharing-Win10.ps1
│   │   └── BACA-INI.md
│   └── Win11/
│       ├── 01-Sharing-Win11.ps1  # Mendukung proteksi Windows 11 & verifikasi WPP
│       └── BACA-INI.md
├── client/                       # Script yang dijalankan di PC yang ingin mencetak
│   ├── Win7/
│   │   ├── 02-Connect-Win7.cmd   # Batch script instan untuk Win7 x64 (tanpa PowerShell)
│   │   ├── 02-Connect-Win7.ps1   # PowerShell script (mendukung mode LocalPort x86)
│   │   └── BACA-INI.md
│   ├── Win10/
│   │   ├── 02-Connect-Win10.ps1
│   │   └── BACA-INI.md
│   └── Win11/
│       ├── 02-Connect-Win11.ps1
│       └── BACA-INI.md
├── tools/                        # Alat bantu diagnosa dan perbaikan
│   ├── 03-Test-PrinterShare.ps1  # Tool diagnosa mandiri (Read-only, aman dijalankan)
│   ├── 04-Fix-LegacyCompat.ps1   # Script standalone pemulihan kompatibilitas Win7
│   ├── 05-Rollback.ps1           # Mengembalikan perubahan Host Windows 10/11
│   ├── 05-Rollback-Win7.ps1      # Mengembalikan perubahan Host Windows 7
│   └── dev/
│       └── Test-Scripts.ps1      # Cek sintaks, kompatibilitas PS 2.0, dan lint
├── tests/                        # Test Pester (menu, struktur, pemeriksa kualitas)
│   ├── Run-Tests.ps1             # Menjalankan seluruh test
│   └── *.Tests.ps1
├── .github/workflows/ci.yml      # CI: lint + test otomatis saat push / pull request
├── .editorconfig                 # Gaya penulisan (encoding, indentasi, akhir baris)
├── CHANGELOG.md                  # Riwayat perubahan
├── VERSION                       # Nomor versi aplikasi
├── LICENSE                       # Lisensi MIT
├── README.md                     # Dokumentasi Bahasa Indonesia
└── README.en.md                  # English Documentation
```

---

## ⚙️ Persiapan Awal

1. **Jalankan Terminal sebagai Administrator**:
   Klik kanan icon Windows Terminal / PowerShell / Command Prompt, lalu pilih **Run as Administrator**.
2. **Izinkan Eksekusi Script PowerShell (hanya sesi berjalan)**:
   Jika muncul peringatan *script execution is disabled*, jalankan:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. **Catatan Khusus Windows 11 (Protected Print Mode)**:
   Jika Host memakai Windows 11, pastikan fitur *Windows Protected Print* dalam posisi nonaktif:
   `Settings` → `Bluetooth & devices` → `Printers & scanners` → matikan **Windows protected print mode**.

---

## 🚀 Cara Cepat (Menu Interaktif)

Tidak ingin mengetik perintah panjang di PowerShell? Cukup pakai **menu interaktif**:

1. Buka folder project ini.
2. Klik dua kali **`Menu.cmd`** (atau ketik `Menu.cmd` di Command Prompt).
3. Pilih **Yes** saat muncul jendela *User Account Control* (UAC) — menu otomatis meminta hak Administrator.
4. Pilih nomor menu, lalu jawab pertanyaan singkat yang muncul.

```text
============================================================
                 PRINTER SHARING TOOLKIT  v1.0.0
============================================================
  OS ini : Windows 10 64-bit
  Printer dibagikan : belum ada

   1. HOST      - Bagikan printer dari PC ini
   2. KLIEN     - Sambungkan ke printer yang dibagikan
   3. DIAGNOSA  - Cek masalah sharing (read-only)
   4. PERBAIKAN - Fix kompatibilitas Windows 7
   5. ROLLBACK  - Kembalikan pengaturan host
   6. LOG       - Lihat log & backup terakhir
   7. BANTUAN   - Panduan singkat & buka README
   8. BAHASA    - Ganti bahasa (ID/EN)
   0. KELUAR
```

Menu otomatis mendeteksi versi Windows (7 / 10 / 11) dan memilih script yang tepat, sehingga Anda tidak perlu menghafal parameter seperti `-PrinterName`, `-Server`, `-ShareName`, atau `-AllowLegacyWin7`.

> [!TIP]
> - **HOST**: pilih menu `1` → `2` untuk membagikan printer. Anda cukup memilih printer dari daftar, lalu menjawab pertanyaan seperti *"Ada klien Windows 7?"*. Menu `1` → `4` untuk berhenti membagikan (unshare).
> - **KLIEN**: pilih menu `2` → `2` untuk menyambung. Khusus Windows 7 32-bit, gunakan pilihan *mode LocalPort* dan masukkan path driver `.inf`.
> - **DIAGNOSA**: pilih menu `3` (aman, tidak mengubah apa pun).
> - **LOG**: pilih menu `6` untuk melihat log/backup terbaru, membuka foldernya, atau menampilkan isinya.
> - **BAHASA**: pilih menu `8` untuk berganti antara Bahasa Indonesia dan English; pilihan disimpan.
> - Menu ini hanya **membungkus** script asli di folder `host\`, `client\`, dan `tools\`; pemakaian manual lewat PowerShell tetap tersedia seperti dijelaskan di bawah.

---

## 📖 Panduan Penggunaan

### Langkah 1 — Setup di PC Host

Lakukan langkah ini pada PC yang tersambung kabel USB ke printer fisik.

1. Buka PowerShell sebagai **Administrator**.
2. Masuk ke direktori toolkit sesuai OS Host:
   ```powershell
   # Contoh jika Host adalah Windows 10:
   cd host\Win10

   # Contoh jika Host adalah Windows 11:
   cd host\Win11

   # Contoh jika Host adalah Windows 7:
   cd host\Win7
   ```
3. Cek daftar printer yang terpasang untuk melihat nama persisnya:
   ```powershell
   .\01-Sharing-Win10.ps1 -ListPrinters
   ```
4. *(Opsional)* Lakukan simulasi (*dry-run*) terlebih dahulu:
   ```powershell
   .\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7 -WhatIf
   ```
5. Terapkan konfigurasi sharing printer:
   ```powershell
   # Jika ada klien Windows 7 di jaringan:
   .\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7

   # Jika semua klien adalah Windows 10 / 11 (mode paling aman):
   .\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series"
   ```

Setelah selesai, script akan menampilkan jalur jaringan (**UNC Path**), contoh:
```text
\\NAMA-PC-HOST\EPSON-L120
```
> [!IMPORTANT]
> Simpan informasi nama komputer (`NAMA-PC-HOST`) dan nama share (`EPSON-L120`) untuk digunakan di PC Klien.

---

### Langkah 2 — Sambungkan dari PC Klien

Lakukan langkah ini pada PC yang ingin mencetak dokumen melalui jaringan.

#### Kasus A: Klien Windows 10 atau Windows 11

Buka PowerShell (disarankan sebagai Administrator jika ingin memasang port/driver otomatis), lalu jalankan:

```powershell
# Untuk Klien Windows 10:
cd client\Win10
.\02-Connect-Win10.ps1 -Server NAMA-PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage

# Untuk Klien Windows 11:
cd client\Win11
.\02-Connect-Win11.ps1 -Server NAMA-PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage
```

> **Tips Kredensial**: Jika Host meminta autentikasi (misal Windows 11 24H2), tambahkan parameter `-SaveCredential` untuk menyimpan login secara permanen di Windows Credential Manager:
> ```powershell
> .\02-Connect-Win10.ps1 -Server NAMA-PC-HOST -ShareName EPSON-L120 -SaveCredential
> ```

---

#### Kasus B: Klien Windows 7 (64-bit)

Bisa menggunakan script Batch biasa (cepat & tanpa repot) atau PowerShell:

- **Cara 1: Batch Command (Paling Mudah)**:
  ```cmd
  cd client\Win7
  02-Connect-Win7.cmd NAMA-PC-HOST EPSON-L120
  ```
- **Cara 2: PowerShell**:
  ```powershell
  cd client\Win7
  .\02-Connect-Win7.ps1 -Server NAMA-PC-HOST -ShareName EPSON-L120 -SetDefault -TestPage
  ```

---

#### Kasus C: Klien Windows 7 (32-bit / x86)

Host modern 64-bit tidak dapat mentransfer driver 32-bit secara otomatis. Solusinya adalah menggunakan mode **LocalPort** bersama driver resmi 32-bit dari vendor printer:

1. Unduh driver printer versi **32-bit (x86)** dari website resmi printer Anda (Epson, Canon, HP, Brother, dll).
2. Ekstrak file driver ke folder lokal, contoh: `C:\Driver\x86\`.
3. Buka PowerShell Administrator di Windows 7:
   ```powershell
   cd client\Win7
   .\02-Connect-Win7.ps1 -Server NAMA-PC-HOST -ShareName EPSON-L120 -Mode LocalPort -DriverInf "C:\Driver\x86\driver.inf" -SetDefault -TestPage
   ```

---

## 🔍 Diagnosa & Pemeriksaan

Jika printer tidak bisa diakses atau Anda ingin mengecek status jaringan tanpa mengubah konfigurasi apa pun, jalankan alat diagnosa (*read-only*):

```powershell
# Cek printer lokal pada PC ini:
.\tools\03-Test-PrinterShare.ps1

# Cek konektivitas ke PC Host dari PC Klien:
.\tools\03-Test-PrinterShare.ps1 -Server NAMA-PC-HOST -ShareName EPSON-L120
```

Script ini akan memeriksa:
- Ketersediaan Port SMB (445) dan RPC (135).
- Status Layanan Windows: `Spooler`, `LanmanServer`, `FDResPub`, dll.
- Kategori Profil Jaringan (Private vs Public).
- Rule Firewall untuk File and Printer Sharing.
- Tipe Driver Printer (Type 3 vs Type 4).
- Konfigurasi Registry mitigasi Point & Print.

---

## 🔄 Rollback (Kembalikan Pengaturan)

Setiap kali script host dijalankan, toolkit otomatis menyimpan status sebelumnya ke folder `C:\ProgramData\PrinterShare\logs\`.

Untuk mengembalikan konfigurasi Host ke kondisi awal:

```powershell
# Untuk Host Windows 10 / Windows 11:
.\tools\05-Rollback.ps1

# Untuk Host Windows 7:
.\tools\05-Rollback-Win7.ps1
```

---

## 🛠️ Tabel Solusi Error Umum

| Kode Error / Gejala | Kemungkinan Penyebab | Solusi Teruji |
|---|---|---|
| **`0x0000011b`** | Host menolak koneksi RPC Spooler tanpa enkripsi (*PrintNightmare patch*). | Jalankan script Host dengan parameter `-AllowLegacyWin7`, atau jalankan `tools\04-Fix-LegacyCompat.ps1 -AllowLegacyWin7` pada Host. |
| **`0x00000bc4`** | Driver printer tidak ditemukan otomatis oleh Klien (*Point and Print Restriction*). | Pada Host: gunakan `-AllowLegacyWin7`. Pada Klien: pastikan driver vendor terpasang atau gunakan parameter `-Mode Legacy`. |
| **`0x00000709`** | Gagal menyetel printer default karena nama printer tidak cocok / spooler crash. | Restart service Print Spooler (`Restart-Service Spooler`) pada Host dan Klien, lalu ulangi perintah koneksi. |
| **`0x0000007e`** | Perbedaan arsitektur sistem (Host 64-bit vs Klien 32-bit). | Pada Klien Windows 7 32-bit, gunakan `02-Connect-Win7.ps1` dengan parameter `-Mode LocalPort` dan sertakan file driver INF 32-bit. |
| **`Akses Ditolak / 0x00000005`** | Autentikasi jaringan gagal / Host mewajibkan login akun lokal. | Buat user lokal berpassword di Host, lalu sambungkan dari Klien dengan menambahkan flag `-SaveCredential`. |
| **Port 445 / 135 Tertutup** | Profil jaringan masih *Public* atau Firewall memblokir koneksi. | Script host otomatis mengubah profil jaringan ke *Private* dan membuka grup firewall File and Printer Sharing. |
| **Printer "Hilang" Setelah Update** | Update Windows mereset konfigurasi RPC atau driver network printer. | Jalankan script Klien kembali dengan menyertakan parameter `-Repair`. |
| **Windows 11 24H2 Gagal Konek** | Kebijakan baru Windows 11 24H2 melarang koneksi SMB Guest tanpa password. | Nonaktifkan guest anonim, buat user lokal dengan password di Host, dan gunakan `-SaveCredential` di Klien. |
| **Windows 11 Tolak Sharing** | Fitur *Windows Protected Print Mode* aktif di Host. | Nonaktifkan fitur tersebut via `Settings` → `Bluetooth & devices` → `Printers & scanners`. |

---

## 🔒 Prinsip Keamanan

1. **SMB1 Ditinggalkan**: Meskipun mendukung Windows 7, toolkit ini beroperasi murni di atas **SMB2/SMB3**. Protokol SMB1 tidak pernah diaktifkan.
2. **Opt-in Compatibility**: Opsi pelonggaran keamanan seperti `-AllowLegacyWin7` dan `-AllowGuest` bersifat **opsional per switch**, dan tidak aktif secara default.
3. **Isolasi Driver LocalPort**: Klien 32-bit tidak dipaksa mengambil driver dari Host 64-bit, melainkan memuat driver lokal terisolasi untuk stabilitas spooler.
4. **Audit & Rollback Penuh**: Seluruh modifikasi registry, status layanan, dan rule firewall tersimpan dalam file cadangan JSON / teks yang dapat dipulihkan sewaktu-waktu.

---

## 🧪 Pengembangan & Pengujian

Sebelum mengubah atau menambah script, jalankan pemeriksa kualitas:

```powershell
.\tools\dev\Test-Scripts.ps1
```

Pemeriksa ini melakukan tiga hal:

1. **Sintaks** - mem-parse semua file `.ps1` untuk memastikan tidak ada error.
2. **Kompatibilitas PowerShell 2.0** - file yang diawali `#Requires -Version 2.0`
   (Menu, Host Win7, Klien Win7, Rollback Win7) tidak boleh memakai konstruksi
   PS 3.0+ (mis. `[ordered]`, `Get-CimInstance`, `$PSScriptRoot`, `ConvertFrom-Json`),
   agar tetap berjalan di Windows 7.
3. **Lint** - menjalankan `PSScriptAnalyzer` dengan `PSScriptAnalyzerSettings.psd1`
   (bila modul terpasang).

Gunakan `-FailOnWarning` untuk memperketat (warning dianggap gagal), atau
`-SkipLint` untuk melewati tahap lint.

Selain itu, tersedia **test Pester** untuk memverifikasi logika menu, kelengkapan
struktur repositori, dan pemeriksa kualitas:

```powershell
.\tests\Run-Tests.ps1
```

Test berjalan di Pester 3.x (bawaan Windows PowerShell 5.1) maupun Pester 5.
Bila Pester belum terpasang:

```powershell
Install-Module Pester -Scope CurrentUser -Force
```

CI GitHub Actions (`.github/workflows/ci.yml`) menjalankan pemeriksaan dan test ini
otomatis pada setiap `push` dan `pull request`.

---

## 📄 Lisensi & Kontribusi

Proyek ini terbuka untuk kontribusi! Jika Anda menemukan bug atau memiliki perbaikan untuk versi Windows tertentu, silakan buka *Issue* atau kirimkan *Pull Request*.

Didistribusikan di bawah lisensi MIT. Silakan gunakan dan sesuaikan untuk kebutuhan kantor, sekolah, atau pribadi.
