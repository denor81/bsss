# 🛡️ BSSS — Basic Server Security Setup

> **Secure your Ubuntu server in one command.** Copy. Paste. Done.

## Purpose

You've just installed a new server and need to configure basic security rules:
- Disable password authentication
- Disable root user login
- Change default SSH port from 22 to a custom port
- Synchronize UFW rules with the new SSH port
- Enable UFW firewall
- ... and avoid accidentally locking yourself out of the server (as often happens...)

This script does everything automatically with foolproof protection.

The motivation behind this script was simply: **laziness**. The laziness of configuring the same parameters repeatedly.

The script allows you to perform all settings with a single click.

**For automatic configuration:**
- You must be connected to the server via SSH key
- Using a user other than root (since during setup, rules prohibiting password and root access will be applied)
- The script will not allow configuration if any requirements are not met

You can also configure each parameter separately from the menu.

## Key Features

**Rollback System**
The script launches a background process waiting for a signal confirming successful user connection with the new settings. If the signal is not received within 300 seconds, a complete rollback of all changes made by the script is initiated. This functionality lets you confidently make changes without fear of losing server access.

**Localization**
The script can be easily localized to any language — all functionality is implemented (currently English and Russian supported).

**Modular Architecture**
The script has a modular architecture and allows easy addition of new modules.

**Comprehensive Logging**
Full logging and bash error capture. Logging to 2 channels — `script_dir/logs` and `journalctl`. Use `journalctl -t bsss --since "5 minutes ago"` to view logs.

**GPG Verification**
Automatic verification of downloaded archive via GPG signature.

**One-line Installation**
Convenient one-line launch without system installation! If desired, you can install it in the system for configuration duration and easily remove it via `bsss -u`.

---

## ⚠️ Important Notes

Currently, limited feedback has been collected, so it is **STRICTLY recommended to use the script ONLY on fresh systems with no critical data!**

**Compatibility:**
- Works ONLY with Ubuntu, not adapted for other systems
- Tested on Ubuntu 20.04 and 24.04

---

## 🚀 One Command

```bash
curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh | sudo bash
```

That's it. Everything else is automatic.

**What happens:**
1. Downloads verified package (GPG signature checked)
2. Installs to your system
3. Opens interactive menu

Choose **Y** for one-time use or **i** for permanent installation.

---

## 🎯 What It Does

### Auto-Setup
**One click to secure everything:**
- Change SSH port (random secure port generated)
- Enable UFW firewall
- Configure system permissions
- Update packages
- **300-second rollback** if anything goes wrong

### Manual Control
Use simple menu to configure:
- SSH port settings
- Firewall rules (UFW)
- User permissions
- System updates
- Full rollback if needed

---

## 🔒 Why It's Safe

**Zero lockout risk:**
- Auto-rollback on connection loss (300-second watchdog)
- Manual rollback anytime from menu
- **See everything happening** — full logging in terminal

**Verified installation:**
- GPG signature verification before run
- No hidden code execution
- Systemd journal: `journalctl -t bsss --since '10 minutes ago'`

**Run anytime:**
- Idempotent — safe to repeat
- Detects existing configurations
- Smart pre-flight checks

---

## 📋 Requirements

**Minimal:**
- Ubuntu Linux
- Root access (sudo)
- Internet connection

**That's it.** No manual config files, no complex commands.

---

## 💡 After Installation

```bash
sudo bsss      # Open menu
sudo bsss -u   # Uninstall
```

---

## 🔍 What's Under the Hood

Built with safety-first engineering:
- **Pipeline architecture** — NUL-separated streams, no temp files
- **No eval** — Strict validation prevents code injection
- **Function contracts** — Every function has clear inputs/outputs
- **Namespaced code** — `ssh::`, `ufw::`, `sys::`, `io::`
- **Triple logging** — Terminal + files + systemd journal

> For developers: See [AGENTS.md](AGENTS.md) for architecture details.

---

## 🌍 Multi-Language

English and Russian. Auto-detected.

---

## 📄 License

MIT — Free to use, modify, distribute.

---

**⭐ Star if it helps you!**
