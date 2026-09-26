#!/bin/bash
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }
INSTALL_DIR="/opt/streamforge"
BACKUP_ROOT="/var/backups/streamforge"
BACKUP_DIR="${1:-}"
[ -n "$BACKUP_DIR" ] || { echo "Usage: streamforge rollback <backup-directory>"; exit 2; }
[ -d "$BACKUP_DIR" ] || { echo "Backup not found: $BACKUP_DIR"; exit 1; }
[ -f "$BACKUP_DIR/streamforge.env" ] || { echo "Invalid StreamForge config backup"; exit 1; }

TMP_DIR="/tmp/streamforge-rollback-$(date +%Y%m%d-%H%M%S)"
cleanup(){ rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "Rolling back configuration from $BACKUP_DIR"
mkdir -p "$TMP_DIR/config"
cp -a "$BACKUP_DIR/." "$TMP_DIR/config/"
chmod -R go-rwx "$TMP_DIR/config"

echo "Restoring previous StreamForge code"
[ -d "$BACKUP_DIR/code" ] || { echo "Code backup not found in $BACKUP_DIR"; exit 1; }
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
rsync -a --delete "$BACKUP_DIR/code/" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/bin/*
cp "$INSTALL_DIR"/systemd/*.service "$INSTALL_DIR"/systemd/*.timer /etc/systemd/system/
systemctl daemon-reload

echo "Restoring configuration"
rm -rf "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"
cp -a "$TMP_DIR/config/." "$CONFIG_DIR/"
chmod 600 "$CONFIG_DIR"/*.env 2>/dev/null || true

"$INSTALL_DIR/bin/streamforge-check" || { echo "Rollback validation failed"; exit 1; }
echo "Rollback complete. No stream service was started, stopped, or restarted."
