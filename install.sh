#!/bin/bash
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }
command -v systemctl >/dev/null || { echo "systemd is required"; exit 1; }
REPO="https://github.com/tonysebastine/StreamForge.git"
if command -v apt-get >/dev/null; then apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y ffmpeg curl python3 git rsync; elif command -v dnf >/dev/null; then dnf install -y ffmpeg curl python3 git; elif command -v yum >/dev/null; then yum install -y ffmpeg curl python3 git; else echo "Unsupported package manager"; exit 1; fi
id streamforge >/dev/null 2>&1 || useradd --system --home /var/lib/streamforge --shell /usr/sbin/nologin streamforge
mkdir -p /opt/streamforge /etc/streamforge /var/lib/streamforge/recordings /var/lib/streamforge/final /var/log/streamforge /opt/streamforge/assets
SRC="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SRC/bin/streamforge" ]; then cp -a "$SRC/." /opt/streamforge/; else rm -rf /tmp/streamforge-install && git clone --depth 1 "$REPO" /tmp/streamforge-install && cp -a /tmp/streamforge-install/. /opt/streamforge/; fi
cp -n /opt/streamforge/config/streamforge.env.example /etc/streamforge/streamforge.env
cp -n /opt/streamforge/config/stream-keys.env.example /etc/streamforge/stream-keys.env
cp -n /opt/streamforge/config/telegram.env.example /etc/streamforge/telegram.env
chown -R streamforge:streamforge /var/lib/streamforge /var/log/streamforge
chmod 600 /etc/streamforge/*.env
chmod +x /opt/streamforge/bin/*
cp /opt/streamforge/systemd/*.service /opt/streamforge/systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable streamforge-vod-watch.timer streamforge-disk-monitor.timer streamforge-status-monitor.timer
printf '%s\n' 'StreamForge installed. Configure /etc/streamforge/*.env and add licensed assets before starting the relay.'
