#!/bin/bash
set -euo pipefail
case "${1:-}" in
status) systemctl is-active streamforge-live.service 2>/dev/null || true; df -hP /var/lib/streamforge;;
start) systemctl start streamforge-live.service;;
stop) systemctl stop streamforge-live.service;;
restart) systemctl restart streamforge-live.service;;
logs) journalctl -u streamforge-live.service -n 30 --no-pager;;
disk) df -hP /var/lib/streamforge;;
*) echo "Allowed: status start stop restart logs disk"; exit 2;; esac
