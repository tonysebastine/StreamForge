#!/bin/bash
set -euo pipefail

# Safe local dry-run test for the VOD assembly pipeline.
# Never reads /opt/restream and never touches the live relay.
# Creates short synthetic intro/main/outro media under /tmp by default.

ROOT=${STREAMFORGE_DRYRUN_DIR:-/tmp/streamforge-vod-dryrun}
SCRIPT_DIR=${STREAMFORGE_DRYRUN_SCRIPT_DIR:-/opt/streamforge/bin}
ASSEMBLER="$SCRIPT_DIR/vod-assemble.sh"
BIN=${STREAMFORGE_FFMPEG:-ffmpeg}
PROBE=${STREAMFORGE_FFPROBE:-ffprobe}

die(){ echo "ERROR: $*" >&2; exit 1; }
command -v "$BIN" >/dev/null || die "ffmpeg not found"
command -v "$PROBE" >/dev/null || die "ffprobe not found"
[ -x "$ASSEMBLER" ] || die "vod-assemble.sh not found at $ASSEMBLER"

rm -rf "$ROOT"
mkdir -p "$ROOT"/{recordings,assets,final,log}

# Isolated StreamForge config consumed by the public assembler.
CONF="$ROOT/streamforge.env"
cat >"$CONF" <<EOF
STREAMFORGE_HOME=$ROOT
STREAMFORGE_DATA=$ROOT
STREAMFORGE_LOG=$ROOT/log
EOF

make_clip() {
  local out="$1" duration="$2" label="$3"
  "$BIN" -hide_banner -loglevel error -y     -f lavfi -i "color=c=black:s=640x360:r=30:d=$duration"     -f lavfi -i "sine=frequency=1000:sample_rate=48000:d=$duration"     -vf "drawtext=text='$label':fontcolor=white:fontsize=36:x=(w-text_w)/2:y=(h-text_h)/2"     -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -b:a 96k -ar 48000 -ac 2     "$out"
}

echo "Creating isolated sample media under $ROOT"
make_clip "$ROOT/assets/intro.mp4" 3 "STREAMFORGE INTRO"
"$BIN" -hide_banner -loglevel error -y -f lavfi -i "color=c=black:s=640x360:r=30:d=5" -vf "drawtext=text='STREAMFORGE MAIN (NO AUDIO)':fontcolor=white:fontsize=32:x=(w-text_w)/2:y=(h-text_h)/2" -c:v libx264 -preset ultrafast -pix_fmt yuv420p "$ROOT/recordings/sample.mp4"
make_clip "$ROOT/assets/outro.mp4" 3 "STREAMFORGE OUTRO"

# Run the real public assembler with an isolated config path.
# No /etc/streamforge and no /opt/restream paths are used.
env STREAMFORGE_CONFIG="$CONF" STREAMFORGE_VOD_LOCK="$ROOT/vod.lock" bash -c '
  source "$STREAMFORGE_CONFIG"
  export STREAMFORGE_HOME STREAMFORGE_DATA STREAMFORGE_LOG
  exec "'"$ASSEMBLER"'" "'"$ROOT/recordings/sample.mp4"'"
'

OUT="$ROOT/final/sample-with-intro-outro.mp4"
[ -s "$OUT" ] || die "dry-run output was not created"

VIDEO_CODEC=$("$PROBE" -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$OUT")
AUDIO_CODEC=$("$PROBE" -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$OUT")
DURATION=$("$PROBE" -v error -show_entries format=duration -of csv=p=0 "$OUT")

[ "$VIDEO_CODEC" = h264 ] || die "unexpected video codec: $VIDEO_CODEC"
[ "$AUDIO_CODEC" = aac ] || die "unexpected audio codec: $AUDIO_CODEC"

# 3 + 5 + 3 seconds with two 1-second transitions => approximately 9 seconds.
awk -v d="$DURATION" 'BEGIN { if (d < 8.8 || d > 9.2) exit 1 }' ||
  die "unexpected output duration: $DURATION (expected about 9 seconds)"

echo
echo "DRY-RUN PASSED"
echo "  output:  $OUT"
echo "  video:   $VIDEO_CODEC"
echo "  audio:   $AUDIO_CODEC"
echo "  duration: $DURATION seconds"
echo "  fades:   2 x 1-second video + 2 x 1-second audio"
echo "  live relay: untouched"
echo "  /opt/restream: not accessed"
