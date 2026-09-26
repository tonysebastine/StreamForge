# Installation

Run `sudo ./install.sh` on a supported systemd Linux server. The installer creates application, configuration, data, and log directories and does not start the live relay automatically.

## Safe updates

Use:

```bash
sudo streamforge update
```

The update workflow:
1. Creates a timestamped backup under `/var/backups/streamforge/`.
2. Backs up `/etc/streamforge/` and the currently installed StreamForge code.
3. Clones the candidate version into an isolated temporary directory.
4. Runs Bash syntax checks, ShellCheck when available, systemd unit validation when available, and the isolated VOD dry-run.
5. Installs the candidate into `/opt/streamforge` only after validation passes.
6. Runs `streamforge-check` after installation.
7. Automatically restores the previous code if post-install validation fails.
8. Never starts, stops, or restarts the live relay.

The update workflow does **not** access or modify `/opt/restream`.

## Rollback

List available backups:

```bash
sudo ls -1 /var/backups/streamforge/
```

Rollback using the selected backup directory:

```bash
sudo streamforge rollback /var/backups/streamforge/YYYYMMDD-HHMMSS
```

Rollback restores both the StreamForge code snapshot and the backed-up `/etc/streamforge/` configuration, then reloads systemd and runs validation. It does not start, stop, or restart the relay.

Keep configuration backups protected because they contain secrets.
