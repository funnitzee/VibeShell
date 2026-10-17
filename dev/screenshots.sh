#!/usr/bin/env bash
# Regenerate the screenshots shown in the README (docs/screenshots/*.png).
#
# Runs the shell in a nested niri window inside the same isolated sandbox as
# dev/run-nested.sh, on a private D-Bus session so nothing from the real session
# (media players, notifications) ends up in a public picture. The terminal shows
# the README only. Old images are overwritten; git history keeps the old ones.
#
# Usage: dev/screenshots.sh [DELAY_SECONDS]   (default 12)
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
SB=${VIBESHELL_SANDBOX:-/tmp/vibeshell-shots}
DELAY=${1:-12}
OUT="$REPO/docs/screenshots"

rm -rf "$SB"
mkdir -p "$SB"/{config/vibeshell,cache,state,data} "$OUT"

# Sample stats quickly so the sparklines are full by the time we take the picture.
echo '{ "stats": { "interval": 400 } }' >"$SB/config/vibeshell/settings.json"

cat >"$SB/niri.kdl" <<EOF
hotkey-overlay {
    skip-at-startup
}

layout {
    gaps 12
    background-color "#0c0c0c"
    focus-ring {
        off
    }
    border {
        on
        width 1
        active-color "#e8e8e8"
        inactive-color "#2e2e2e"
    }
    default-column-width { proportion 0.62; }
}

screenshot-path "$SB/raw.png"

spawn-sh-at-startup "quickshell -p $REPO/shell/shell.qml > $SB/qs.log 2>&1"
spawn-sh-at-startup "sleep 2; cd $REPO && kitty --title VibeShell -o background=#0c0c0c -o background_opacity=1.0 -o foreground=#e8e8e8 -o font_size=11 sh -c 'head -n 26 README.md; sleep 120'"
spawn-sh-at-startup "for d in 0.5 1.2 0.4 1.6 0.4 0.9; do for i in \$(seq \$(nproc)); do timeout \$d sh -c 'while :; do :; done' & done; wait; sleep \$d; done"
spawn-sh-at-startup "sleep $DELAY; niri msg action screenshot-screen; sleep 1; niri msg action quit --skip-confirmation"
EOF

export XDG_CONFIG_HOME=$SB/config
export XDG_CACHE_HOME=$SB/cache
export XDG_STATE_HOME=$SB/state
export XDG_DATA_HOME=$SB/data
export VIBESHELL_CONFIG_DIR=$SB/config/vibeshell

niri validate -c "$SB/niri.kdl" >/dev/null
dbus-run-session -- niri -c "$SB/niri.kdl" >"$SB/niri.log" 2>&1 || true

[[ -f $SB/raw.png ]] || {
    echo "No screenshot was produced, see $SB/niri.log and $SB/qs.log" >&2
    exit 1
}

# Bar height = bar + gap above and below, read from the shipped defaults.
BAR_H=$(python3 -I - "$REPO/shell/defaults/settings.json" <<'PY'
import json, sys
bar = json.load(open(sys.argv[1]))["bar"]
print(bar["height"] + 2 * bar["gap"])
PY
)
WIDTH=$(magick identify -format '%w' "$SB/raw.png")

cp "$SB/raw.png" "$OUT/desktop.png"
magick "$SB/raw.png" -crop "${WIDTH}x${BAR_H}+0+0" +repage -filter point -resize 200% "$OUT/bar.png"

echo "Wrote $OUT/desktop.png and $OUT/bar.png"
