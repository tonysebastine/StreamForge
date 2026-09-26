#!/bin/bash
set -euo pipefail
source /etc/streamforge/streamforge.env
for f in "$STREAMFORGE_DATA/recordings"/*.mp4; do [ -f "$f" ] || continue; [ -f "$f.complete" ] || continue; /opt/streamforge/bin/vod-assemble.sh "$f"; done
