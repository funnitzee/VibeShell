#!/usr/bin/env bash
# Run VibeShell inside a nested niri window with an isolated sandbox.
# Nothing outside $SB (default /tmp/vibeshell-dev) is touched: XDG dirs are redirected there.
#
# Usage: dev/run-nested.sh [--shot SECONDS]
#   --shot N   take a screenshot after N seconds, then quit (for headless checks)
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
SB=${VIBESHELL_SANDBOX:-/tmp/vibeshell-dev}

mkdir -p "$SB"/{config/vibeshell,cache,state,data}
sed "s|@REPO@|$REPO|g;s|@SB@|$SB|g" "$REPO/dev/niri-dev.kdl" > "$SB/niri.kdl"

if [[ ${1:-} == --shot ]]; then
    echo "spawn-sh-at-startup \"sleep ${2:-5}; niri msg action screenshot-screen; sleep 1; niri msg action quit --skip-confirmation\"" >> "$SB/niri.kdl"
fi

export XDG_CONFIG_HOME=$SB/config
export XDG_CACHE_HOME=$SB/cache
export XDG_STATE_HOME=$SB/state
export XDG_DATA_HOME=$SB/data
export VIBESHELL_CONFIG_DIR=$SB/config/vibeshell

niri validate -c "$SB/niri.kdl"
exec niri -c "$SB/niri.kdl"
