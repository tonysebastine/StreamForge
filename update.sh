#!/bin/bash
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exit 1
[ -d /opt/streamforge/.git ] || { echo "Update requires a git checkout at /opt/streamforge"; exit 1; }
git -C /opt/streamforge pull --ff-only
systemctl daemon-reload
echo "Updated; /etc/streamforge configuration was preserved."
