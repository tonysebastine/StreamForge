#!/bin/bash
set -euo pipefail
exec ffmpeg -hide_banner -loglevel warning "$@"
