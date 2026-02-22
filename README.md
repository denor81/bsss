# 🛡️ BSSS — Basic Server Security Setup

> **Secure your Ubuntu server in one command.** Copy. Paste. Done.

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
