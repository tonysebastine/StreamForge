#!/bin/bash
set -euo pipefail
[ -r /etc/streamforge/telegram.env ] || exit 0
source /etc/streamforge/telegram.env
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ] || exit 0
curl -fsS --max-time 15 -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" --data-urlencode "text=${1:-StreamForge alert}" >/dev/null
