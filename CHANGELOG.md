# Changelog

## v1.2
- All example values made generic (network `172.16.50.0/24`, `DEPLOYSRV\svc_imaging`, alias names)
- MIT license and disclaimer added

## v1.1 — 2026-11-21
- Detailed documentation split into 7 files (architecture, implementation, runbook, troubleshooting, AD, security/maintenance, lessons learned)
- Implementation guide: reference VM is written manually (not via Deploy.ps1) so Audit Mode stays reachable

## v1.0 — 2026-11-18
- First production version: custom WinPE + Deploy.ps1 (disk selection, SIL confirmation, GPT/UEFI, DISM apply, bcdboot)
- FirstLogon.ps1 v2: auto-logon cleanup, System Restore, forced language list (copied to new users), PC name, standard user, AD mode switch
- unattend template with matching LocalAccount/AutoLogon placeholders, LogonCount 3, classic AZ Latin keyboard
