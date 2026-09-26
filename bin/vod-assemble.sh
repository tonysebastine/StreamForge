#!/bin/bash
set -euo pipefail
source /etc/streamforge/streamforge.env
REC="$STREAMFORGE_DATA/recordings"; ASSETS="$STREAMFORGE_HOME/assets"; FINAL="$STREAMFORGE_DATA/final"; LOG="$STREAMFORGE_LOG/vod-assemble.log"
LOCK=/run/lock/streamforge-vod-assemble.lock
mkdir -p "$REC" "$FINAL" "$(dirname "$LOG")"; exec 9>"$LOCK"; flock -n 9 || { echo "VOD assembly already running" >&2; exit 1; }
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }; fail(){ log "ERROR: $*"; exit 1; }
INPUT="${1:-}"
if [ -z "$INPUT" ]; then INPUT=$(find "$REC" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.ts' -o -iname '*.m4v' -o -iname '*.webm' \) -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-); fi
[ -n "$INPUT" ] && [ -f "$INPUT" ] || fail "No VOD recording found"
[ -f "$ASSETS/intro.mp4" ] && [ -f "$ASSETS/outro.mp4" ] || fail "Missing intro.mp4 or outro.mp4"
NAME=$(basename "${INPUT%.*}"); OUTPUT="$FINAL/${NAME}-with-intro-outro.mp4"; WORK="$FINAL/.work-$NAME"
[ -f "$OUTPUT" ] && { log "Output already exists: $OUTPUT"; exit 0; }; mkdir -p "$WORK"
cleanup(){ rc=$?; [ "$rc" -eq 0 ] && rm -rf "$WORK" || log "Failure; preserving $WORK"; }; trap cleanup EXIT
read -r W H FPS < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$INPUT" | awk -F, '{split($3,a,"/"); if(a[2]==0)a[2]=1; printf "%d %d %.6f\n",$1,$2,a[1]/a[2]}')
[ -n "${W:-}" ] && [ -n "${H:-}" ] && [ -n "${FPS:-}" ] || fail "Could not read video parameters"
normalize(){ ffmpeg -hide_banner -loglevel warning -y -i "$1" -vf "scale=$W:$H:force_original_aspect_ratio=decrease,pad=$W:$H:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=$FPS" -c:v libx264 -preset veryfast -pix_fmt yuv420p -r "$FPS" -c:a aac -b:a 128k -ar 48000 -ac 2 -movflags +faststart "$2"; }
log "Normalizing intro"; normalize "$ASSETS/intro.mp4" "$WORK/intro.mp4"
log "Normalizing recording"; normalize "$INPUT" "$WORK/recording.mp4"
log "Normalizing outro"; normalize "$ASSETS/outro.mp4" "$WORK/outro.mp4"
INTRO_D=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$WORK/intro.mp4")
REC_D=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$WORK/recording.mp4")
OFFSET1=$(awk -v d="$INTRO_D" 'BEGIN{v=d-1;if(v<0)v=0;printf "%.6f",v}')
OFFSET2=$(awk -v a="$INTRO_D" -v b="$REC_D" 'BEGIN{v=a+b-2;if(v<0)v=0;printf "%.6f",v}')
log "Applying exactly 1-second intro-to-video and video-to-outro crossfades"
ffmpeg -hide_banner -loglevel warning -y -i "$WORK/intro.mp4" -i "$WORK/recording.mp4" -i "$WORK/outro.mp4" -filter_complex "[0:v]settb=AVTB,setpts=PTS-STARTPTS[v0];[1:v]settb=AVTB,setpts=PTS-STARTPTS[v1];[2:v]settb=AVTB,setpts=PTS-STARTPTS[v2];[0:a]aresample=48000,asetpts=PTS-STARTPTS[a0];[1:a]aresample=48000,asetpts=PTS-STARTPTS[a1];[2:a]aresample=48000,asetpts=PTS-STARTPTS[a2];[v0][v1]xfade=transition=fade:duration=1:offset=$OFFSET1[v01];[v01][v2]xfade=transition=fade:duration=1:offset=$OFFSET2[vout];[a0][a1]acrossfade=d=1:c1=tri:c2=tri[a01];[a01][a2]acrossfade=d=1:c1=tri:c2=tri[aout]" -map "[vout]" -map "[aout]" -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac -b:a 128k -ar 48000 -ac 2 -movflags +faststart "$OUTPUT"
ffprobe -v error -show_entries format=duration,size -show_entries stream=index,codec_name,codec_type,width,height,r_frame_rate,sample_rate,channels -of default=noprint_wrappers=1 "$OUTPUT" | tee -a "$LOG"
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$OUTPUT" | grep -qx h264 || fail "Video validation failed"
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$OUTPUT" | grep -qx aac || fail "Audio validation failed"
log "VOD assembly complete: $OUTPUT"
