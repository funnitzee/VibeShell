#!/usr/bin/env bash
# Regenerate the screenshots shown in the README (docs/screenshots/*.png).
#
# Runs the shell in a nested niri window inside the same isolated sandbox as
# dev/run-nested.sh, on a private D-Bus session so nothing from the real session
# (media players, notifications) ends up in a public picture. The terminal shows
# the README only; the second picture shows the command palette; the third the
# dashboard (`call dashboard open`); the fourth the quick settings (`call quick
# open`); the fifth the settings window (`call settings open`); the sixth a stack
# of notifications. A fake MPRIS player (dev/mock-player.py) provides something
# to show in the media widgets. niri emits its own "screenshot saved"
# notification, so the popup is cleared before every shot bar the last one. Old
# images are overwritten; git history keeps the old ones.
#
# Usage: dev/screenshots.sh [DELAY_SECONDS]   (default 12)
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
SB=${VIBESHELL_SANDBOX:-/tmp/vibeshell-shots}
DELAY=${1:-12}
OUT="$REPO/docs/screenshots"

rm -rf "$SB"
mkdir -p "$SB"/{config/vibeshell,cache,state,data,bin} "$OUT"

# Sample stats quickly so the sparklines are full by the time we take the picture.
echo '{ "stats": { "interval": 400 } }' >"$SB/config/vibeshell/settings.json"

# Fake brightnessctl so the quick settings preview shows the brightness row even
# on machines without the package (same idea as the mock MPRIS player above).
cat >"$SB/bin/brightnessctl" <<'EOS'
#!/usr/bin/env bash
case "$1" in
  get) echo 15600 ;;
  max) echo 24000 ;;
  set) exit 0 ;;
  *) exit 1 ;;
esac
EOS
chmod +x "$SB/bin/brightnessctl"

# Fake gammastep / powerprofilesctl so the quick settings preview also shows the
# night-light and power-profile rows on machines without those packages.
cat >"$SB/bin/gammastep" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
chmod +x "$SB/bin/gammastep"

cat >"$SB/bin/powerprofilesctl" <<'EOS'
#!/usr/bin/env bash
case "$1" in
  list) printf '  performance:\n    Driver: placeholder\n  power-saver:\n    Driver: placeholder\n\n* balanced:\n    Driver: placeholder\n' ;;
  *) exit 0 ;;
esac
EOS
chmod +x "$SB/bin/powerprofilesctl"

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

screenshot-path "$SB/shot-%H%M%S.png"

spawn-sh-at-startup "python3 -I $REPO/dev/mock-player.py > $SB/mock-player.log 2>&1"
spawn-sh-at-startup "quickshell -p $REPO/shell/shell.qml > $SB/qs.log 2>&1"
spawn-sh-at-startup "sleep 2; cd $REPO && kitty --title VibeShell -o background=#0c0c0c -o background_opacity=1.0 -o foreground=#e8e8e8 -o font_size=11 sh -c 'head -n 26 README.md; sleep 120'"
spawn-sh-at-startup "for d in 0.5 1.2 0.4 1.6 0.4 0.9; do for i in \$(seq \$(nproc)); do timeout \$d sh -c 'while :; do :; done' & done; wait; sleep \$d; done"
spawn-sh-at-startup "sleep $DELAY; niri msg action screenshot-screen; sleep 1; quickshell ipc -p $REPO/shell/shell.qml call notify clear; quickshell ipc -p $REPO/shell/shell.qml call palette open :; sleep 2; niri msg action screenshot-screen; sleep 1; quickshell ipc -p $REPO/shell/shell.qml call notify clear; quickshell ipc -p $REPO/shell/shell.qml call palette hide; quickshell ipc -p $REPO/shell/shell.qml call dashboard open; sleep 2; niri msg action screenshot-screen; sleep 1; quickshell ipc -p $REPO/shell/shell.qml call notify clear; quickshell ipc -p $REPO/shell/shell.qml call dashboard hide; quickshell ipc -p $REPO/shell/shell.qml call quick open; sleep 3; niri msg action screenshot-screen; sleep 1; quickshell ipc -p $REPO/shell/shell.qml call notify clear; quickshell ipc -p $REPO/shell/shell.qml call quick hide; quickshell ipc -p $REPO/shell/shell.qml call settings open; sleep 2; niri msg action screenshot-screen; sleep 1; quickshell ipc -p $REPO/shell/shell.qml call settings hide; quickshell ipc -p $REPO/shell/shell.qml call notify clear; sleep 1; notify-send -a Spotify 'Spotify' 'Now playing: Boards of Canada - Roygbiv'; notify-send -a Updates -u normal 'System update' '12 packages can be upgraded'; notify-send -a Battery -u critical 'Battery low' '5% remaining, plug in now'; sleep 2; niri msg action screenshot-screen; sleep 1; niri msg action quit --skip-confirmation"
EOF

export XDG_CONFIG_HOME=$SB/config
export XDG_CACHE_HOME=$SB/cache
export XDG_STATE_HOME=$SB/state
export XDG_DATA_HOME=$SB/data
export VIBESHELL_CONFIG_DIR=$SB/config/vibeshell
export PATH="$SB/bin:$PATH"

niri validate -c "$SB/niri.kdl" >/dev/null
dbus-run-session -- niri -c "$SB/niri.kdl" >"$SB/niri.log" 2>&1 || true

# Shots are named by time, so sorting gives: 1) desktop, 2) palette, 3) dashboard, 4) quick settings, 5) settings, 6) notifications.
mapfile -t SHOTS < <(ls "$SB"/shot-*.png 2>/dev/null | sort)
((${#SHOTS[@]} == 6)) || {
    echo "Expected 6 screenshots, got ${#SHOTS[@]}, see $SB/niri.log and $SB/qs.log" >&2
    exit 1
}

# Bar height = bar + gap above and below, read from the shipped defaults.
BAR_H=$(python3 -I - "$REPO/shell/defaults/settings.json" <<'PY'
import json, sys
bar = json.load(open(sys.argv[1]))["bar"]
print(bar["height"] + 2 * bar["gap"])
PY
)
WIDTH=$(magick identify -format '%w' "${SHOTS[0]}")

cp "${SHOTS[0]}" "$OUT/desktop.png"
cp "${SHOTS[1]}" "$OUT/palette.png"
cp "${SHOTS[2]}" "$OUT/dashboard.png"
cp "${SHOTS[3]}" "$OUT/quick.png"
cp "${SHOTS[4]}" "$OUT/settings.png"
cp "${SHOTS[5]}" "$OUT/notify.png"
magick "${SHOTS[0]}" -crop "${WIDTH}x${BAR_H}+0+0" +repage -filter point -resize 200% "$OUT/bar.png"

echo "Wrote $OUT/desktop.png, $OUT/bar.png, $OUT/palette.png, $OUT/dashboard.png, $OUT/quick.png, $OUT/settings.png and $OUT/notify.png"
