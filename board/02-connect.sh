#!/bin/sh
# Downloads the compiled .eim for this board once, so batch inference never
# re-fetches the model.
#
#   EI_API_KEY=ei_xxx sh 02-connect.sh
#
# The runner authenticates with the project API key directly, so the
# interactive edge-impulse-linux wizard (and its Ctrl+C) isn't needed.
# Without EI_API_KEY the runner falls back to its own login prompt.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/00-ledger.sh"
[ -f "$HOME/.profile" ] && . "$HOME/.profile"

MODEL="${MODEL:-$HOME/qdc/model.eim}"
mkdir -p "$(dirname "$MODEL")"
set --
[ -z "${EI_API_KEY:-}" ] || set -- --api-key "$EI_API_KEY"

ledger download_start
edge-impulse-linux-runner "$@" --download "$MODEL"
ls -lh "$MODEL"
ledger download_done
