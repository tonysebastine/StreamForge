#!/bin/bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }
REPO_URL="${STREAMFORGE_REPO_URL:-https://github.com/tonysebastine/StreamForge.git}"
INSTALL_DIR="/opt/streamforge"
CONFIG_DIR="/etc/streamforge"
BACKUP_ROOT="/var/backups/streamforge"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"
TMP_DIR="/tmp/streamforge-update-$STAMP"

cleanup(){ rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "Backing up $CONFIG_DIR to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
if [ -d "$CONFIG_DIR" ]; then
  cp -a "$CONFIG_DIR/." "$BACKUP_DIR/"
fi
chmod -R go-rwx "$BACKUP_DIR"

echo "Fetching candidate version"
git clone --depth 1 "$REPO_URL" "$TMP_DIR"
[ -f "$TMP_DIR/install.sh" ] || { echo "Candidate validation failed: install.sh missing"; exit 1; }

echo "Validating candidate"
for f in "$TMP_DIR"/bin/*.sh "$TMP_DIR"/install.sh "$TMP_DIR"/update.sh "$TMP_DIR"/uninstall.sh; do
  [ -f "$f" ] && bash -n "$f"
done
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$TMP_DIR"/bin/*.sh "$TMP_DIR"/install.sh "$TMP_DIR"/update.sh "$TMP_DIR"/uninstall.sh
fi
if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze verify "$TMP_DIR"/systemd/*.service "$TMP_DIR"/systemd/*.timer
fi
if [ -x "$TMP_DIR/bin/vod-dry-run.sh" ]; then
  STREAMFORGE_DRYRUN_SCRIPT_DIR="$TMP_DIR/bin" "$TMP_DIR/bin/vod-dry-run.sh"
fi

echo "Backing up current StreamForge code"
mkdir -p "$BACKUP_DIR/code"
rsync -a --delete --exclude=".git" "$INSTALL_DIR/" "$BACKUP_DIR/code/"

echo "Installing candidate without touching $CONFIG_DIR"
mkdir -p "$INSTALL_DIR"
rsync -a --delete --exclude=".git" "$TMP_DIR/" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/bin/*
cp "$INSTALL_DIR"/systemd/*.service "$INSTALL_DIR"/systemd/*.timer /etc/systemd/system/
systemctl daemon-reload

echo "Revalidating installed version"
"$INSTALL_DIR/bin/streamforge-check" || {
  echo "Installed validation failed; restoring previous code automatically" >&2
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  rsync -a --delete --exclude=".git" "$BACKUP_DIR/code/" "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR"/bin/*
  cp "$INSTALL_DIR"/systemd/*.service "$INSTALL_DIR"/systemd/*.timer /etc/systemd/system/
  systemctl daemon-reload
  exit 1
}

echo "Update complete"
echo "Configuration backup: $BACKUP_DIR"
echo "No stream service was started, stopped, or restarted."
echo "$INSTALL_DIR was updated; $CONFIG_DIR was preserved."
