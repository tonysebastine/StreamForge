#!/bin/bash
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exit 1
systemctl disable --now streamforge-vod-watch.timer streamforge-disk-monitor.timer streamforge-status-monitor.timer 2>/dev/null || true
systemctl disable --now streamforge-live.service streamforge-telegram-bot.service 2>/dev/null || true
rm -f /etc/systemd/system/streamforge-*.service /etc/systemd/system/streamforge-*.timer
systemctl daemon-reload
rm -rf /opt/streamforge
echo "Code removed. /etc/streamforge and /var/lib/streamforge were preserved."
