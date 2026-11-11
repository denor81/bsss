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
- Application logging to terminal, files, and systemd journal
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

### User sudo status

User creation explains the selected sudo mode and asks for confirmation before making changes. Password-protected sudo uses a shared 30-minute authentication cache across the user's terminal sessions. Passwordless sudo does not prompt for a password; the account itself still receives a password.

The BSSS user's information row includes `sudocache`, read from the user's sudo policy rather than just the file created by BSSS:

```text
2. bsssuser|id:1000|sudo:pass|sudocache:30m
```

- `30m` (or another duration): explicitly configured timeout in minutes.
- `no`: caching is disabled (`timestamp_timeout=0` or `!timestamp_timeout`).
- `default`: no explicit timeout; sudo uses its built-in default.
- `unlimited`: a negative timeout, with no time-based expiry until reboot or explicit invalidation.
- `n/a`: no sudo access, or no password is required.
- `mixed`: command/runas-specific overrides prevent a single reliable summary.

This reports configuration, not whether a cached authentication is currently valid. The check uses noninteractive `sudo -ll`; policy or parsing failures are not reported as disabled caching.

## Logs

```bash
journalctl -t bsss --since "10 minutes ago"
```

### Package command output

Package index updates, installations, system upgrades, and `unattended-upgrades` reconfiguration use the controlling terminal directly so interactive package dialogs remain usable. This applies to dependency installation during startup and one-line installation, system updates from the menu or auto-setup, UFW installation, and auto-update setup. Updating BSSS itself uses the same one-line installer path.

Raw package output is not captured in BSSS log files or forwarded to the journal by BSSS. BSSS confirmations and status messages are still logged. These commands require a controlling terminal; existing noninteractive options remain unchanged.

## License

MIT
