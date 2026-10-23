#!/bin/sh
# Start an owned model server; save per-image responses and stop it on exit.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/00-ledger.sh"
DIR="${1:-$HOME/qdc/test-images}"
MODEL="${MODEL:-$HOME/qdc/model.eim}"
OUT="${OUT:-$HOME/qdc/results.txt}"
PORT="${PORT:-1337}"
SERVER_LOG="${SERVER_LOG:-$HOME/qdc/server.log}"
URL="http://127.0.0.1:$PORT/api/image"
case "$PORT" in ''|*[!0-9]*) echo 'PORT must be an integer.' >&2; exit 1 ;; esac
[ "$PORT" -ge 1024 ] && [ "$PORT" -le 65535 ] || { echo 'PORT must be 1024..65535.' >&2; exit 1; }
[ -d "$DIR" ] || { echo "Image folder not found: $DIR" >&2; exit 1; }
[ -f "$MODEL" ] || { echo "Model not found: $MODEL (run 02-connect.sh)." >&2; exit 1; }
command -v curl >/dev/null || { echo 'curl is required.' >&2; exit 1; }
command -v edge-impulse-linux-runner >/dev/null || { echo 'Run 01-setup.sh first.' >&2; exit 1; }
[ ! -e "$OUT" ] || { echo "Refusing to overwrite $OUT. Move it or set OUT to a new filename." >&2; exit 1; }
total=0
for f in "$DIR"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.jpg|*.jpeg|*.png|*.JPG|*.JPEG|*.PNG) total=$((total + 1)) ;; esac
done
[ "$total" -gt 0 ] || { echo "No JPEG/PNG images in $DIR." >&2; exit 1; }
if curl -sS --max-time 2 -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
    echo "Port $PORT already serves HTTP. Stop that server or choose another PORT; its model is unknown." >&2
    exit 1
fi
if command -v ss >/dev/null 2>&1 && ss -H -ltn "sport = :$PORT" | grep -q .; then
    echo "Port $PORT is already listening. Choose a different PORT." >&2
    exit 1
fi
mkdir -p "$(dirname "$OUT")" "$(dirname "$SERVER_LOG")"
chmod +x "$MODEL"
runner_pid=''
cleanup() {
    if [ -n "$runner_pid" ]; then
        kill "$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
edge-impulse-linux-runner --model-file "$MODEL" --run-http-server "$PORT" > "$SERVER_LOG" 2>&1 &
runner_pid=$!
i=0
until curl -sS --max-time 2 -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; do
    if ! kill -0 "$runner_pid" 2>/dev/null || [ "$i" -ge 60 ]; then
        echo "Runner failed to start. See $SERVER_LOG" >&2
        cat "$SERVER_LOG" >&2
        exit 1
    fi
    i=$((i + 1))
    sleep 1
done
kill -0 "$runner_pid" 2>/dev/null || { echo 'Runner exited during startup.' >&2; exit 1; }
: > "$OUT"
n=0
ledger infer_start
for f in "$DIR"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.jpg|*.jpeg|*.png|*.JPG|*.JPEG|*.PNG) ;; *) continue ;; esac
    n=$((n + 1))
    t0=$(now_ms)
    if ! res=$(curl --fail-with-body -sS --connect-timeout 5 --max-time 60 -X POST -F "file=@\"$f\"" "$URL"); then
        printf '### %s 0\n%s\n' "$(basename "$f")" "$res" >> "$OUT"
        ledger infer_failed
        echo "Request failed for $f. Partial results saved to $OUT." >&2
        exit 1
    fi
    t1=$(now_ms)
    printf '### %s %s\n%s\n' "$(basename "$f")" "$((t1 - t0))" "$res" >> "$OUT"
    printf '[%d/%d] %s %sms\n' "$n" "$total" "$(basename "$f")" "$((t1 - t0))"
done
ledger infer_done
echo "Results: $OUT ($n images). Runner stops when this script exits."
echo 'Download results and ledger, then click End Session in QDC.'
