# 🛡️ BSSS — Basic Server Security Setup

One-command baseline hardening for a fresh Ubuntu server, with automatic rollback if the new SSH settings lock you out.

## Purpose

Secure a new server quickly and safely:
- Disable SSH password auth
- Disable root login
- Change SSH port and sync UFW rules
- Enable UFW
- Optional swap file setup

Auto-setup requires:
- SSH key login
- A non-root user (sudo)

You can also configure each part from the menu.

## Key Features

- Rollback watchdog (300s) to prevent lockouts
- Full logging to terminal, files, and systemd journal
- Modular architecture
- GPG-verified one-line installer

## Compatibility

- Ubuntu only (20.04–24.04 tested)
- Uses sshd `Include` configs, so older Ubuntu is not supported

## One Command

```bash
curl -fsSL https://raw.githubusercontent.com/denor81/bsss/main/oneline-runner.sh | sudo bash
```

## Usage

```bash
sudo bsss      # Run menu
sudo bsss -u   # Uninstall
```

## Logs

```bash
journalctl -t bsss --since "10 minutes ago"
```

## License

MIT
