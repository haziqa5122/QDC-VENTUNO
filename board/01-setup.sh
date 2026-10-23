#!/bin/sh
# Installs the Edge Impulse Linux CLI on the QDC board, but first records
# whether a previous session's install survived (STATE=WARM / STATE=COLD).
#
# VENTUNO Q runs Ubuntu, so this follows the Edge Impulse VENTUNO Q docs
# (apt + NodeSource + npm -g). Other board operating systems are not supported.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/00-ledger.sh"

ledger setup_start
EI_LINUX_VERSION="${EI_LINUX_VERSION:-1.25.2}"

echo "=== Board ==="
cat /etc/os-release 2>/dev/null | grep -E '^(NAME|VERSION|ID)=' || uname -a
echo "model:  $(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo unknown)"
echo "kernel: $(uname -r)  arch: $(uname -m)  user: $(whoami)"
echo "apt:    $(command -v apt-get || echo none)"
echo "sudo:   $(sudo -n true 2>/dev/null && echo passwordless || echo 'needs password / unavailable')"
echo "node:   $(node --version 2>/dev/null || echo none)"
echo "app-cli: $(command -v arduino-app-cli || echo none)"
echo "NPU:    $(ls /dev 2>/dev/null | grep -iE 'fastrpc|adsprpc' | tr '\n' ' ' || true)"
echo "disk:   $(df -h "$HOME" | awk 'NR==2{print $4}') free in $HOME"

# Pick up a previous install if one exists
[ -f "$HOME/.profile" ] && . "$HOME/.profile"

if command -v edge-impulse-linux >/dev/null 2>&1; then
    installed_version=$(edge-impulse-linux --version 2>/dev/null)
    if [ "$installed_version" = "$EI_LINUX_VERSION" ]; then
        echo "STATE=WARM (CLI $installed_version already present)"
        ledger setup_warm
        ledger setup_done
        exit 0
    fi
    echo "CLI $installed_version found; installing requested $EI_LINUX_VERSION."
fi

echo "STATE=COLD  (no CLI found, installing)"
ledger setup_cold

if command -v apt-get >/dev/null 2>&1; then
    echo "apt found -> Edge Impulse VENTUNO Q install path"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    node_major=$(node --version 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
    if [ -z "$node_major" ] || [ "$node_major" -lt 20 ]; then
        nodesource_script=$(mktemp)
        curl -fsSL https://deb.nodesource.com/setup_20.x -o "$nodesource_script"
        sudo bash "$nodesource_script"
        rm -f "$nodesource_script"
    fi
    sudo apt-get install -y gcc g++ make build-essential nodejs sox \
        gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-base gstreamer1.0-plugins-base-apps
    ledger setup_apt_done
    sudo npm install -g "edge-impulse-linux@$EI_LINUX_VERSION" --unsafe-perm
else
    echo 'This helper targets Ubuntu on VENTUNO Q; apt-get is required.' >&2
    exit 1
fi

edge-impulse-linux --version
ledger setup_done
