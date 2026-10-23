# Source this file, then call:  ledger <phase_name>
# Appends "epoch,iso_time,phase" to $LEDGER and echoes it, so the line can be
# copied out even if the session is torn down before the file is downloaded.
LEDGER="${LEDGER:-$HOME/qdc/ledger.csv}"
mkdir -p "$(dirname "$LEDGER")"
[ -f "$LEDGER" ] || echo "epoch,time,phase" > "$LEDGER"

ledger() {
    _line="$(date +%s),$(date -u +%Y-%m-%dT%H:%M:%SZ),$1"
    echo "$_line" >> "$LEDGER"
    echo "[ledger] $_line"
}

# Milliseconds since epoch; busybox date has no %N, so fall back to seconds.
now_ms() {
    _ns=$(date +%s%N 2>/dev/null)
    case "$_ns" in
        *N|"") echo $(( $(date +%s) * 1000 )) ;;
        *) echo $(( _ns / 1000000 )) ;;
    esac
}
