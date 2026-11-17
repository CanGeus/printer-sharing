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

A PowerShell and Batch automation toolkit designed to share a locally attached **USB printer** from a Host PC to other Client PCs across a local network reliably and securely using **SMB2 (no SMB1 required)**.

Specifically built to eliminate recurring Windows printer sharing errors caused by post-*PrintNightmare* security hardening, RPC authentication restrictions, and Windows 11 24H2 security policies, including:
- `0x0000011b` (*RPC authentication level privacy*)
- `0x00000bc4` (*Printer driver was not found / Point and Print policy*)
- `0x00000709` (*Cannot set default printer*)
- `0x0000007e` (*Architecture mismatch: 32-bit x86 vs 64-bit x64*)
- `0x00000005` (*Access Denied / Guest connection restrictions*)
- Network printers randomly disappearing or going offline after cumulative Windows updates.

---

## 📑 Table of Contents

- [Key Features](#-key-features)
- [Compatibility Matrix (Host × Client)](#-compatibility-matrix-host--client)
- [Directory Structure](#-directory-structure)
- [Prerequisites](#-prerequisites)
- [Quick Start (Interactive Menu)](#-quick-start-interactive-menu)
- [Quick Start Guide](#-quick-start-guide)
  - [Step 1: Setup on the Host PC](#step-1--setup-on-the-host-pc)
  - [Step 2: Connect from Client PCs](#step-2--connect-from-client-pcs)
- [Diagnostics & Verification](#-diagnostics--verification)
- [Rollback (Restore Defaults)](#-rollback-restore-defaults)
- [Common Troubleshooting & Error Codes](#-common-troubleshooting--error-codes)
- [Security Principles](#-security-principles)
- [Development & Testing](#-development--testing)

---

## 🚀 Key Features

- **Secure & Modern**: Operates purely over **SMB2/SMB3**. Insecure, legacy **SMB1 remains completely disabled**.
- **Cross-Windows Compatibility**: Smoothly bridges Windows 7 (32-bit & 64-bit), Windows 10, and Windows 11 (including build 24H2).
- **Automated Host Configuration**: Automatically adjusts Network Profile to *Private*, configures firewall rules, starts discovery services (*Spooler*, *LanmanServer*, *FDResPub*, *upnphost*), and configures share permissions.
- **Cross-Architecture Support**: Built-in `-Mode LocalPort` workflow allows 32-bit (x86) Windows 7 clients to print to 64-bit (x64) hosts without driver architecture conflicts.
- **Dry-Run Mode (`-WhatIf`)**: Safely test and preview all changes before applying them.
- **Automated Rollback Journal**: Saves state snapshots in JSON / text logs, allowing you to restore the system to its prior state with a single command.

---

## 🧭 Compatibility Matrix (Host × Client)

Always run the script that matches the **Client's OS** (not the Host's OS):

| Host (USB Printer Attached) ↓ / Client → | Win 7 (64-bit) Client | Win 7 (32-bit) Client | Win 10 Client | Win 11 Client |
|---|---|---|---|---|
| **Windows 7 Host** | `client\Win7\02-Connect-Win7.cmd`<br>or `.ps1` | `client\Win7\02-Connect-Win7.ps1`<br>`-Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |
| **Windows 10 Host** | `client\Win7\02-Connect-Win7.cmd`<br>or `.ps1` | `client\Win7\02-Connect-Win7.ps1`<br>`-Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |
| **Windows 11 Host** *(incl. 24H2)* | `client\Win7\02-Connect-Win7.cmd`<br>or `.ps1` | `client\Win7\02-Connect-Win7.ps1`<br>`-Mode LocalPort` | `client\Win10\02-Connect-Win10.ps1` | `client\Win11\02-Connect-Win11.ps1` |

> [!NOTE]
> - **Windows 7 32-bit (x86) Clients**: Must use `-Mode LocalPort` combined with official 32-bit vendor INF driver files.
> - **Windows 11 (Build 24H2+) Hosts**: Microsoft blocks unauthenticated guest access by default. Ensure the Host has a password-protected local account and connect from the client using `-SaveCredential`.
> - **Driver Type 4**: Windows 11 frequently installs generic *Type 4 (IPP/Class)* drivers that cannot be shared with Windows 7. Install the manufacturer's official *Type 3* driver on the Host.

---

## 📂 Directory Structure

```text
printer-share-toolkit/
├── Menu.cmd                      # Interactive menu launcher (double-click, auto-Administrator)
├── Menu.ps1                      # Menu logic (PowerShell 2.0+ compatible)
├── host/                         # Scripts to execute on the PC physically connected to the printer
│   ├── Win7/
│   │   ├── 01-Sharing-Win7.ps1   # PowerShell 2.0 compatible
│   │   └── BACA-INI.md
│   ├── Win10/
│   │   ├── 01-Sharing-Win10.ps1
│   │   └── BACA-INI.md
│   └── Win11/
│       ├── 01-Sharing-Win11.ps1  # Includes Windows 11 & WPP verification
│       └── BACA-INI.md
├── client/                       # Scripts to execute on PCs that need to print
│   ├── Win7/
│   │   ├── 02-Connect-Win7.cmd   # Instant batch script for Win7 x64 (no PS required)
│   │   ├── 02-Connect-Win7.ps1   # PowerShell script (supports x86 LocalPort mode)
│   │   └── BACA-INI.md
│   ├── Win10/
│   │   ├── 02-Connect-Win10.ps1
│   │   └── BACA-INI.md
│   └── Win11/
│       ├── 02-Connect-Win11.ps1
│       └── BACA-INI.md
├── tools/                        # Diagnostic and recovery utilities
│   ├── 03-Test-PrinterShare.ps1  # Non-destructive diagnostic auditor (Read-only)
│   ├── 04-Fix-LegacyCompat.ps1   # Standalone legacy Win7 compatibility patcher
│   ├── 05-Rollback.ps1           # Rollback changes on Windows 10/11 Hosts
│   ├── 05-Rollback-Win7.ps1      # Rollback changes on Windows 7 Hosts
│   └── dev/
│       └── Test-Scripts.ps1      # Syntax, PS 2.0 compatibility, and lint checks
├── .github/workflows/ci.yml      # CI: automated lint on push / pull request
├── CHANGELOG.md                  # Change history
├── VERSION                       # Application version
├── LICENSE                       # MIT License
├── README.md                     # Indonesian Documentation
└── README.en.md                  # English Documentation
```

---

## ⚙️ Prerequisites

1. **Run as Administrator**:
   Right-click PowerShell or Command Prompt and choose **Run as Administrator**.
2. **Set Execution Policy (Current Process Only)**:
   If PowerShell blocks script execution, run:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. **Special Windows 11 Note (Protected Print Mode)**:
   If your Host runs Windows 11, ensure *Windows Protected Print Mode* is turned off:
   Go to `Settings` → `Bluetooth & devices` → `Printers & scanners` → turn off **Windows protected print mode**.

---

## 🚀 Quick Start (Interactive Menu)

Don't want to type long PowerShell commands? Use the **interactive menu** instead:

1. Open this project folder.
2. Double-click **`Menu.cmd`** (or type `Menu.cmd` in Command Prompt).
3. Choose **Yes** on the *User Account Control* (UAC) prompt — the menu requests Administrator rights automatically.
4. Pick a menu number, then answer the short prompts.

```text
============================================================
                 PRINTER SHARING TOOLKIT
============================================================
  OS ini : Windows 10 64-bit

   1. HOST      - Bagikan printer dari PC ini
   2. KLIEN     - Sambungkan ke printer yang dibagikan
   3. DIAGNOSA  - Cek masalah sharing (read-only)
   4. PERBAIKAN - Fix kompatibilitas Windows 7
   5. ROLLBACK  - Kembalikan pengaturan host
   0. Keluar
```

The menu detects your Windows version (7 / 10 / 11) and picks the right script, so you never have to remember parameters like `-PrinterName`, `-Server`, `-ShareName`, or `-AllowLegacyWin7`.

> [!TIP]
> - **HOST**: choose `1` → `2` to share a printer. Just pick the printer from the list and answer prompts such as *"Are there Windows 7 clients?"*.
> - **CLIENT**: choose `2` → `2` to connect. For Windows 7 32-bit, use the *LocalPort* option and provide the `.inf` driver path.
> - **DIAGNOSTICS**: choose `3` (safe, changes nothing).
> - The menu only **wraps** the original scripts in `host\`, `client\`, and `tools\`; manual PowerShell usage below still works exactly as before.

---

## 📖 Quick Start Guide

### Step 1 — Setup on the Host PC

Perform these steps on the PC connected to the printer via USB.

1. Open PowerShell as **Administrator**.
2. Navigate to the appropriate folder according to the Host's OS:
   ```powershell
   # If Host is Windows 10:
   cd host\Win10

   # If Host is Windows 11:
   cd host\Win11

   # If Host is Windows 7:
   cd host\Win7
   ```
3. List installed printers to verify the exact printer name:
   ```powershell
   .\01-Sharing-Win10.ps1 -ListPrinters
   ```
4. *(Optional)* Perform a dry-run to preview actions:
   ```powershell
   .\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7 -WhatIf
   ```
5. Apply the sharing configuration:
   ```powershell
   # If you have Windows 7 client computers on the network:
   .\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series" -AllowLegacyWin7

   # If ALL clients are Windows 10 / 11 (maximum security):
   .\01-Sharing-Win10.ps1 -PrinterName "EPSON L120 Series"
   ```

Upon completion, the script outputs the network path (**UNC Path**), e.g.:
```text
\\HOST-PC-NAME\EPSON-L120
```
> [!IMPORTANT]
> Note down the computer name (`HOST-PC-NAME`) and share name (`EPSON-L120`) for client configuration.

---

### Step 2 — Connect from Client PCs

Perform these steps on the computer from which you want to print.

#### Scenario A: Windows 10 or Windows 11 Client

Open PowerShell (Administrator recommended for seamless driver installation):

```powershell
# For Windows 10 Client:
cd client\Win10
.\02-Connect-Win10.ps1 -Server HOST-PC-NAME -ShareName EPSON-L120 -SetDefault -TestPage

# For Windows 11 Client:
cd client\Win11
.\02-Connect-Win11.ps1 -Server HOST-PC-NAME -ShareName EPSON-L120 -SetDefault -TestPage
```

> **Credential Tip**: If the Host requires authentication (e.g., Windows 11 24H2), append `-SaveCredential` to store login credentials permanently in Windows Credential Manager:
> ```powershell
> .\02-Connect-Win10.ps1 -Server HOST-PC-NAME -ShareName EPSON-L120 -SaveCredential
> ```

---

#### Scenario B: Windows 7 (64-bit) Client

You can use the simple batch file (no PowerShell required) or the PowerShell script:

- **Option 1: Batch Script (Fastest & Simplest)**:
  ```cmd
  cd client\Win7
  02-Connect-Win7.cmd HOST-PC-NAME EPSON-L120
  ```
- **Option 2: PowerShell Script**:
  ```powershell
  cd client\Win7
  .\02-Connect-Win7.ps1 -Server HOST-PC-NAME -ShareName EPSON-L120 -SetDefault -TestPage
  ```

---

#### Scenario C: Windows 7 (32-bit / x86) Client

Modern 64-bit hosts cannot serve 32-bit print drivers automatically. The recommended solution is **LocalPort** mode paired with official 32-bit vendor drivers:

1. Download the **32-bit (x86)** driver from the manufacturer's website (Epson, Canon, HP, Brother, etc.).
2. Extract the driver archive to a local path, such as `C:\Driver\x86\`.
3. Open an elevated PowerShell terminal on the Windows 7 client:
   ```powershell
   cd client\Win7
   .\02-Connect-Win7.ps1 -Server HOST-PC-NAME -ShareName EPSON-L120 -Mode LocalPort -DriverInf "C:\Driver\x86\driver.inf" -SetDefault -TestPage
   ```

---

## 🔍 Diagnostics & Verification

If connection issues occur or you wish to audit network readiness without changing system settings, run the read-only diagnostic utility:

```powershell
# Check local printer readiness on the current PC:
.\tools\03-Test-PrinterShare.ps1

# Check end-to-end connectivity from Client to Host:
.\tools\03-Test-PrinterShare.ps1 -Server HOST-PC-NAME -ShareName EPSON-L120
```

This diagnostic script validates:
- SMB port (445) and RPC endpoint mapper (135) reachability.
- Status of key background services: `Spooler`, `LanmanServer`, `FDResPub`, etc.
- Network Profile Category (Private vs. Public).
- Windows Firewall rules for File and Printer Sharing.
- Printer Driver Type (Type 3 vs. Type 4).
- Point and Print registry policy mitigations.

---

## 🔄 Rollback (Restore Defaults)

Whenever a host script runs, a complete backup state is saved to `C:\ProgramData\PrinterShare\logs\`.

To revert all modifications back to their original state:

```powershell
# For Windows 10 / Windows 11 Hosts:
.\tools\05-Rollback.ps1

# For Windows 7 Hosts:
.\tools\05-Rollback-Win7.ps1
```

---

## 🛠️ Common Troubleshooting & Error Codes

| Error Code / Symptom | Root Cause | Verified Resolution |
|---|---|---|
| **`0x0000011b`** | Host enforces RPC spooler encryption (*PrintNightmare hardening*). | Run the Host script with `-AllowLegacyWin7`, or execute `tools\04-Fix-LegacyCompat.ps1 -AllowLegacyWin7` on the Host. |
| **`0x00000bc4`** | Client cannot locate or install the remote printer driver (*Point and Print policy*). | On Host: add `-AllowLegacyWin7`. On Client: ensure vendor driver is pre-installed or use `-Mode Legacy`. |
| **`0x00000709`** | Default printer assignment failed or spooler process hung. | Restart the Print Spooler (`Restart-Service Spooler`) on both Host and Client, then retry connection. |
| **`0x0000007e`** | Driver architecture mismatch (64-bit Host vs 32-bit Client). | On 32-bit Windows 7 client, use `02-Connect-Win7.ps1` with `-Mode LocalPort` and specify the 32-bit INF file. |
| **`Access Denied / 0x00000005`** | Network authentication rejected / Host requires credentials. | Create a local password-protected account on Host and connect using `-SaveCredential` on Client. |
| **Ports 445 / 135 Filtered** | Network Profile is set to *Public* or Windows Firewall is blocking traffic. | The host script automatically switches the active profile to *Private* and enables File & Printer Sharing rules. |
| **Printer Missing After Update** | Windows Update refreshed RPC spooler policies or network device cache. | Re-run the client connection script with the `-Repair` parameter. |
| **Windows 11 24H2 Connection Fails** | Stricter Windows 11 24H2 security blocks anonymous guest access over SMB. | Disable guest fallbacks; configure a named user account with password on the Host and use `-SaveCredential` on the Client. |
| **Windows 11 Cannot Share** | *Windows Protected Print Mode* is turned on. | Disable it in `Settings` → `Bluetooth & devices` → `Printers & scanners`. |

---

## 🔒 Security Principles

1. **No Insecure SMB1**: While backward compatible with Windows 7, this toolkit communicates exclusively over **SMB2/SMB3**. Insecure SMB1 is never enabled.
2. **Opt-in Legacy Compatibility**: Compatibility relaxations such as `-AllowLegacyWin7` and `-AllowGuest` are strictly opt-in flags.
3. **Driver Isolation via LocalPort**: 32-bit clients use local vendor drivers rather than pulling unsigned or mismatched drivers from the Host.
4. **Complete Auditability & Rollback**: Every registry change, firewall rule adjustment, and service configuration is logged and fully reversible.

---

## 🧪 Development & Testing

Before changing or adding scripts, run the quality checks:

```powershell
.\tools\dev\Test-Scripts.ps1
```

It performs three checks:

1. **Syntax** - parses every `.ps1` file to ensure there are no errors.
2. **PowerShell 2.0 compatibility** - files starting with `#Requires -Version 2.0`
   (menu, Win7 Host, Win7 Client, Win7 Rollback) must avoid PS 3.0+ constructs
   (e.g. `[ordered]`, `Get-CimInstance`, `$PSScriptRoot`, `ConvertFrom-Json`)
   so they keep working on Windows 7.
3. **Lint** - runs `PSScriptAnalyzer` with `PSScriptAnalyzerSettings.psd1`
   (when the module is installed).

Use `-FailOnWarning` to be stricter (warnings count as failures), or
`-SkipLint` to skip the lint stage.

GitHub Actions CI (`.github/workflows/ci.yml`) runs these checks automatically
on every `push` and `pull request`.

---

## 📄 Contributing & License

Contributions, feedback, and issue reports are welcome! If you encounter an edge case with a specific printer model or Windows update, feel free to submit an issue or pull request.

Distributed under the **MIT License**. Free for personal, academic, and commercial use.
