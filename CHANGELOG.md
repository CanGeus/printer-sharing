# Changelog

Semua perubahan penting pada proyek ini didokumentasikan di file ini.

Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
dan proyek ini memakai [Semantic Versioning](https://semver.org/lang/id/).

## [Unreleased]

### Added

- **Menu interaktif** diperluas:
  - **LOG** - melihat daftar log/backup terbaru, membuka foldernya, dan menampilkan isi log.
  - **BANTUAN** - panduan singkat dan tombol untuk membuka README.
  - **BAHASA** - berganti bahasa Indonesia/English; pilihan disimpan.
  - **Unshare** - berhenti membagikan printer langsung dari menu HOST.
  - Status printer yang sedang dibagikan ditampilkan di header menu.
- **Test Pester** (`tests/`) untuk logika menu, kelengkapan struktur repositori,
  dan pemeriksa kualitas, plus runner `tests/Run-Tests.ps1`.
- **`.editorconfig`** untuk menyeragamkan encoding, indentasi, dan akhir baris antar editor.
- CI kini juga menjalankan test Pester (`test` job) selain lint.

### Fixed

- Test Pester kini kompatibel dengan Pester 5/6 (yang dipakai CI), bukan hanya
  Pester 3.x: setup dipindah ke `BeforeAll` karena Pester 5+ menjalankan setiap
  `It` di scope terpisah.
- CI memasang Pester pada rentang versi 5.0.0-6.99.99 agar hasilnya dapat diulang.

## [1.0.0] - 2026-11-17

Rilis publik pertama.

### Added

- **Menu interaktif** `Menu.cmd` + `Menu.ps1`:
  - Launcher Command Prompt yang otomatis meminta hak Administrator (UAC).
  - Deteksi otomatis versi Windows (7 / 10 / 11) dan arsitektur (32/64-bit).
  - Menu HOST, KLIEN, DIAGNOSA, PERBAIKAN, dan ROLLBACK tanpa perlu mengetik parameter.
  - Kompatibel PowerShell 2.0 (Windows 7) sampai 5.1+ (Windows 10/11).
- **Script Host** untuk membagikan printer USB melalui SMB2 (tanpa SMB1):
  - `host/Win7/01-Sharing-Win7.ps1` (PowerShell 2.0)
  - `host/Win10/01-Sharing-Win10.ps1`
  - `host/Win11/01-Sharing-Win11.ps1` (termasuk deteksi Windows Protected Print Mode)
- **Script Klien** untuk menyambung ke printer yang dibagikan:
  - `client/Win7/02-Connect-Win7.cmd` (batch, Win7 64-bit)
  - `client/Win7/02-Connect-Win7.ps1` (mendukung mode `LocalPort` untuk Win7 32-bit)
  - `client/Win10/02-Connect-Win10.ps1`
  - `client/Win11/02-Connect-Win11.ps1`
- **Alat bantu**:
  - `tools/03-Test-PrinterShare.ps1` - diagnosa read-only.
  - `tools/04-Fix-LegacyCompat.ps1` - perbaikan kompatibilitas Windows 7.
  - `tools/05-Rollback.ps1` - rollback host Windows 10/11.
  - `tools/05-Rollback-Win7.ps1` - rollback host Windows 7.
- **Perkakas pengembangan**:
  - `tools/dev/Test-Scripts.ps1` - cek sintaks, kompatibilitas PowerShell 2.0, dan lint.
  - `PSScriptAnalyzerSettings.psd1` - konfigurasi lint.
  - CI GitHub Actions (`.github/workflows/ci.yml`).
- Dokumentasi dwibahasa `README.md` (Indonesia) dan `README.en.md` (English).
- File `LICENSE` (MIT) dan `VERSION`.

### Security

- Protokol usang **SMB1 tidak pernah diaktifkan**; hanya SMB2/SMB3.
- Opsi pelonggaran keamanan (`-AllowLegacyWin7`, `-AllowGuest`) bersifat opt-in.
- Setiap perubahan konfigurasi dicatat ke jurnal backup untuk rollback.
