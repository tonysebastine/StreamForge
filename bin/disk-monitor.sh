#!/bin/bash
set -euo pipefail
source /etc/streamforge/streamforge.env
PCT=$(df -P "$STREAMFORGE_DATA" | awk 'NR==2{gsub(/%/,"",$5);print $5}')
if [ "$PCT" -ge "${DISK_ALERT_PERCENT:-85}" ]; then /opt/streamforge/bin/telegram-notify.sh "StreamForge disk warning: $PCT% used" || true; fi
