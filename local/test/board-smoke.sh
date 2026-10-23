#!/bin/sh
# Offline control-flow tests; mocks do not install software or run a real model.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/images" "$TMP/work"
export MOCK_READY="$TMP/ready"
export MOCK_STOPPED="$TMP/stopped"
export EXPECT_KEY='test key with spaces'
export LEDGER="$TMP/ledger.csv"
export MODEL="$TMP/model.eim"
export OUT="$TMP/results.txt"
export SERVER_LOG="$TMP/server.log"
export PORT=41337
export PATH="$TMP/bin:$PATH"
printf 'not a real model' > "$MODEL"
printf 'not a real image' > "$TMP/images/daisy.sample one.PNG"
cat > "$TMP/bin/edge-impulse-linux-runner" <<'MOCK'
#!/bin/sh
if [ "${1:-}" = '--api-key' ]; then
    [ "$2" = "$EXPECT_KEY" ] || exit 9
    [ "$3" = '--download' ] || exit 9
    printf model > "$4"
    exit 0
fi
trap 'rm -f "$MOCK_READY"; touch "$MOCK_STOPPED"; exit 0' TERM INT
: > "$MOCK_READY"
while :; do sleep 1; done
MOCK
cat > "$TMP/bin/curl" <<'MOCK'
#!/bin/sh
for arg in "$@"; do url=$arg; done
case "$url" in
  */api/image)
    if [ "${MOCK_FAIL:-0}" = 1 ]; then printf '{"error":"synthetic failure"}'; exit 22; fi
    printf '{"result":{"classification":{"daisy":1,"roses":0}},"timing":{"classification":2,"dsp":1}}'
    ;;
  *) [ -f "$MOCK_READY" ] ;;
esac
MOCK
chmod +x "$TMP/bin/edge-impulse-linux-runner" "$TMP/bin/curl"
EI_API_KEY="$EXPECT_KEY" sh "$ROOT/board/02-connect.sh" > "$TMP/download.log"
[ -s "$MODEL" ]
sh "$ROOT/board/03-batch-infer.sh" "$TMP/images" > "$TMP/run.log"
[ -f "$MOCK_STOPPED" ]
[ ! -f "$MOCK_READY" ]
grep -q '### daisy.sample one.PNG' "$OUT"
grep -q 'infer_done' "$LEDGER"
if sh "$ROOT/board/03-batch-infer.sh" "$TMP/images" > "$TMP/overwrite.log" 2>&1; then exit 1; fi
grep -q 'Refusing to overwrite' "$TMP/overwrite.log"
OUT="$TMP/empty.txt"
export OUT
if sh "$ROOT/board/03-batch-infer.sh" "$TMP/work" > "$TMP/empty.log" 2>&1; then exit 1; fi
grep -q 'No JPEG/PNG' "$TMP/empty.log"
: > "$MOCK_READY"
if sh "$ROOT/board/03-batch-infer.sh" "$TMP/images" > "$TMP/occupied.log" 2>&1; then exit 1; fi
grep -q 'already serves HTTP' "$TMP/occupied.log"
rm "$MOCK_READY"
export LEDGER="$TMP/failed-ledger.csv"
export OUT="$TMP/failed-results.txt"
export MOCK_FAIL=1
if sh "$ROOT/board/03-batch-infer.sh" "$TMP/images" > "$TMP/failed.log" 2>&1; then exit 1; fi
grep -q infer_failed "$LEDGER"
if grep -q infer_done "$LEDGER"; then exit 1; fi
[ ! -f "$MOCK_READY" ]
printf 'PASS: quoted authentication, batch success, runner cleanup, overwrite refusal, empty folder, occupied port, HTTP failure.\n'
