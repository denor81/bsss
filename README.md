# 🛡️ BSSS — Basic Server Security Setup

> **Secure your Ubuntu server in seconds.** Safe, simple, no complex configuration needed.

---

## ✨ Why BSSS?

- **🚀 One command to run** — No installation required
- **🔒 SSH port changer** — Move away from default port 22 effortlessly
- **🌐 Firewall control** — Enable/disable UFW with confidence
- **🛡️ Auto-rollback** — Revert changes if connection is lost (4-second watchdog)
- **📝 Triple logging** — Terminal + files + systemd journal
- **🌍 Multi-language** — English and Russian support
- **♻️ Idempotent** — Run again anytime, safely

---

## ⚡ Quick Start

### Try Now (One-Time Run)

```bash
curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh | sudo bash
```

Choose **Y** for one-time run or **n** to install system-wide.

### Install Permanently

```bash
curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh | sudo bash
# Choose 'n' when prompted
```

After installation:
```bash
sudo bsss      # Run anytime
sudo bsss -u   # Uninstall
```

---

## 🎯 What It Does

BSSS is a modular framework that automates Linux server security:

- **Change SSH port** — Generates a random secure port or choose your own
- **Configure UFW firewall** — Simple rules, automatic validation
- **Safety mechanisms** — Watchdog protects against lockouts
- **Check system health** — Automatic pre-flight diagnostics

**Designed for simplicity.** No manual config editing, no complex commands.

---

## 🏗️ Under the Hood

Built with **pipeline-first architecture** and **Bash engineering best practices**:

- **Streaming data flow** — NUL-separated pipes (gawk, xargs, sort)
- **Function contracts** — Clear stdin/stdout/exit codes
- **Namespaced functions** — `ssh::`, `ufw::`, `sys::`, `io::`
- **No eval** — Strict validation prevents injection
- **Modular system** — Auto-discovery with metadata tags

> For developers: See [AGENTS.md](AGENTS.md) for architecture details.

---

## 📋 Requirements

- Ubuntu Linux
- Root access (sudo)
- Bash 4+
- gawk (GNU Awk)
- curl

---

## 📄 License

MIT License — Free to use, modify, and distribute.

---

**⭐ Star this repo if it helps you!**
