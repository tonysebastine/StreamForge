#!/bin/bash
set -euo pipefail
source /etc/streamforge/streamforge.env
REC="$STREAMFORGE_DATA/recordings"; ASSETS="$STREAMFORGE_HOME/assets"; FINAL="$STREAMFORGE_DATA/final"
mkdir -p "$REC" "$FINAL"
INPUT="\${1:-}"
if [ -z "$INPUT" ]; then INPUT=$(find "$REC" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-); fi
[ -n "$INPUT" ] && [ -f "$INPUT" ] || { echo "No recording found" >&2; exit 2; }
[ -f "$ASSETS/intro.mp4" ] && [ -f "$ASSETS/outro.mp4" ] || { echo "Add licensed intro.mp4 and outro.mp4" >&2; exit 3; }
NAME=$(basename "\${INPUT%.*}"); OUT="$FINAL/\${NAME}-with-intro-outro.mp4"; WORK="$FINAL/.work-$NAME"; mkdir -p "$WORK"
read -r W H FPS < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$INPUT" | awk -F, '{split($3,a,"/"); print $1,$2,a[1]/a[2]}')
for part in intro recording outro; do src="$ASSETS/intro.mp4"; [ "$part" = recording ] && src="$INPUT"; [ "$part" = outro ] && src="$ASSETS/outro.mp4"; ffmpeg -hide_banner -loglevel warning -y -i "$src" -vf "scale=$W:$H:force_original_aspect_ratio=decrease,pad=$W:$H:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$FPS" -c:v libx264 -preset veryfast -pix_fmt yuv420p -r "$FPS" -c:a aac -b:a 128k -ar 48000 -ac 2 -movflags +faststart "$WORK/$part.mp4"; done
printf "file '%s'\nfile '%s'\nfile '%s'\n" "$WORK/intro.mp4" "$WORK/recording.mp4" "$WORK/outro.mp4" > "$WORK/concat.txt"
ffmpeg -hide_banner -loglevel warning -y -f concat -safe 0 -i "$WORK/concat.txt" -c copy -movflags +faststart "$OUT"
ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,codec_type,width,height,r_frame_rate,sample_rate,channels -of default=noprint_wrappers=1 "$OUT"
rm -rf "$WORK"
