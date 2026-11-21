# WDS Deployment Kit — Zero-Touch-ish Windows 11 over PXE

A small, portable Windows 11 deployment system for small and mid-sized companies **without SCCM/MDT/Intune**.
A technician plugs a PC into an isolated deploy switch, picks network boot, types one confirmation word and
answers two questions. ~20–30 minutes later the PC runs a pre-built Windows 11 image with the company's apps,
correct language/keyboard/time zone, a local admin account and a standard user.

Built and running in production at a mid-sized company. Documentation inside `docs/` is in Azerbaijani.

## Why this exists

- MDT is retired and WDS can no longer run Windows 11 Setup from `boot.wim` ("WDS mode" is blocked).
- WDS can still **PXE-boot a custom WinPE**. This kit uses exactly that: WDS only delivers WinPE,
  and a PowerShell script inside WinPE applies the image from an SMB share with DISM — the same pattern
  SCCM/MDT use under the hood.

## Architecture

```
New PC ──► Deploy switch (isolated, never uplinked to LAN)
              │
              ▼
   Deploy network 172.16.50.0/24 (example)
   ├─ Firewall/Router  .1   DHCP (NO option 60/66/67), DNS, NAT to internet, blocks LAN + lab
   ├─ WDS server       .10  PXE + TFTP -> WinPE (boot.wim) · SMB share \\WDS\Deploy (images + scripts)
   └─ Reference VM          Audit Mode -> Sysprep -> DISM capture -> Win11-Base.wim
```

## Flow

1. **PXE** – firewall DHCP gives an IP; WDS (same L2) answers PXE itself (no DHCP options needed).
2. **TFTP** – WDS sends our custom WinPE (`boot.wim`) into RAM.
3. **startnet.cmd** (inside WinPE) – waits for network, maps the share (read-only account), starts `Deploy.ps1`.
4. **Deploy.ps1** – finds the internal disk (skips USB/SD, asks if more than one), warns in red if Windows
   exists, requires typing `SIL` to wipe, partitions GPT/UEFI, `dism /Apply-Image`, copies the **latest**
   `unattend.xml` + `FirstLogon.ps1` from the share, `bcdboot`, reboots.
5. **unattend.xml** – skips OOBE, sets keyboards/locale/time zone, creates the local admin, auto-logs on once.
6. **FirstLogon.ps1** – removes auto-logon password remnants, enables System Restore, forces the language list,
   shows This PC/Control Panel for new users, asks for PC name and creates a standard (non-admin) user, reboots.

Because steps 4–6 read their files from the share at deploy time, changing `unattend.xml` or the scripts
**never requires rebuilding the image**. Only `startnet.cmd` lives inside `boot.wim`.

## Repository layout

```
scripts/
  Deploy.ps1              runs in WinPE: disk selection, confirmation, partition, apply, bcdboot
  FirstLogon.ps1          runs at first logon: cleanup, restore, languages, PC name, user
  startnet.cmd            goes into boot.wim: connects to the share and starts Deploy.ps1
  unattend.template.xml   answer-file template (placeholders, no secrets)
docs/                     (Azerbaijani)
  01-architecture.md            concepts, components, full technical flow, folders, accounts
  02-implementation-guide.md    build it at a new company from zero, step by step with checks
  03-runbook-operations.md      deploy a PC, change scripts, rebuild boot.wim, refresh the image
  04-troubleshooting.md         symptom → cause → fix tables, logs, FAQ
  05-active-directory.md        domain join options, firewall ports, LAPS, GPO, pitfalls
  06-security-and-maintenance.md known risks, rules, one-time cleanup, periodic maintenance
  07-lessons-learned.md         20 traps hit during the first build
```

## Documentation index

| # | Document | Read it when |
| --- | --- | --- |
| 01 | [Architecture](docs/01-architecture.md) | You want to understand how it works |
| 02 | [Implementation guide](docs/02-implementation-guide.md) | You build it at a new site |
| 03 | [Runbook](docs/03-runbook-operations.md) | You deploy PCs or change something |
| 04 | [Troubleshooting & FAQ](docs/04-troubleshooting.md) | Something does not work |
| 05 | [Active Directory](docs/05-active-directory.md) | The site has (or will have) AD |
| 06 | [Security & maintenance](docs/06-security-and-maintenance.md) | Hand-over and periodic checks |
| 07 | [Lessons learned](docs/07-lessons-learned.md) | Before you start, to skip known traps |

## Quick start

1. Read `docs/02-implementation-guide.md` and fill in the site parameter table.
2. Copy `scripts/` to `E:\Deploy\Scripts` on the WDS server.
3. `unattend.template.xml` → save as `unattend.xml`, replace `ADMIN_ADI` and `ADMIN_SIFRE` (**2 places each, identical**).
4. `startnet.cmd` → set server IP, server name, share account password; inject into `boot.wim`.
5. Set `$Company` in `Deploy.ps1` and `FirstLogon.ps1`; set languages and `$CreateLocalUser` in `FirstLogon.ps1`.

## Security notes

- The deploy network is the main control: isolated subnet, firewall blocks production/lab, deploy switch is
  labelled and never connected to the LAN (otherwise its DHCP becomes a rogue DHCP).
- The share account password is stored in `boot.wim` → the account is **read-only**; captures use a separate admin.
- `unattend.xml` contains the local admin password in clear text → never committed (see `.gitignore`);
  `FirstLogon.ps1` deletes it from deployed PCs. Long-term: Active Directory + **Windows LAPS** for unique admin passwords.
- End users are standard users, not local admins.
- Only licensed or free software goes into the image; no activators.

## Lessons learned (short)

| Trap | Fix |
| --- | --- |
| Windows 11 `boot.wim` blocked in WDS mode | Custom WinPE + share + DISM |
| `SetupComplete.cmd` skipped on OEM-key PCs (HP/Lenovo/ASUS) | `FirstLogonCommands` + `FirstLogon.ps1` |
| Sysprep fails: Store app / language pack installed per user | No Store apps or manual language packs in the reference |
| DISM "hangs" for hours | CMD QuickEdit: a click froze the console → press Esc |
| "Password incorrect" at first logon | Admin name/password must match in `LocalAccount` and `AutoLogon` |
| VMXNET3 in a VM that boots WinPE | No driver in WinPE → use E1000E |
| Legacy-BIOS PCs | Script writes UEFI/GPT → use the UEFI network boot entry |
| Small system disk on the WDS server | C: ≥ 80 GB, keep ADK and images on a data disk |

## Requirements

Windows Server 2022/2025 with the WDS role (supported on Server 2025; Microsoft has announced deprecation in
a later Server release), Windows ADK + WinPE add-on, a Windows 11 ISO, a router/firewall that can serve DHCP on
an isolated subnet, UEFI clients (TPM 2.0 for supported Windows 11).

## License and disclaimer

MIT — see [LICENSE](LICENSE). Provided as-is. `Deploy.ps1` **wipes the selected disk**: test in a lab first,
replace every example value (IP, server name, accounts, passwords) with your own, and never commit a filled
`unattend.xml` or `startnet.cmd`.
