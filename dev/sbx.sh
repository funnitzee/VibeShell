#!/usr/bin/env bash
# Helper for the persistent nested-niri sandbox: run quickshell IPC inside the
# sandbox's private D-Bus session (never the live one), and restart just the
# shell after a code change without tearing down the nested niri window.
#
# Usage:
#   dev/sbx.sh call <target> <fn> [args...]   run one IPC call, print the result
#   dev/sbx.sh restart                         respawn quickshell inside the sandbox
#   dev/sbx.sh status                          niri + quickshell + readiness
#   dev/sbx.sh shot [name]                     screenshot the nested niri output
#
# The sandbox window is started separately with:  dev/run-nested.sh
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
SB=${VIBESHELL_SANDBOX:-/tmp/vibeshell-dev}
QML="$REPO/shell/shell.qml"

niri_pid() {
    pgrep -f "niri -c $SB/niri.kdl" | head -1 || true
}

env_of() { tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null; }
env_get() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }

# The isolated XDG dirs and the private session bus come from the nested niri
# (run-nested.sh exports them, then execs niri). The display is the shell's own
# Wayland socket (wayland-2, ...), not niri's inherited one (wayland-1), so IPC
# must target that. Re-export both on every call *and* before respawning the
# shell — otherwise a restart would inherit this script's env and read/write the
# real ~/.config instead of the sandbox.
sandbox_env() {
    local qs niri; qs=$(pgrep -f "quickshell -p $QML" | head -1 || true); niri=$(niri_pid)
    local base; base=${niri:-$qs}
    [[ -n "$base" ]] || { echo "sandbox not running" >&2; return 1; }
    local b n; b=$(env_of "$niri"); n=$(env_of "$qs")
    local v val
    for v in XDG_CONFIG_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_HOME \
             XDG_RUNTIME_DIR VIBESHELL_CONFIG_DIR DBUS_SESSION_BUS_ADDRESS; do
        val=$(env_get "$b" "$v"); [[ -n "$val" ]] && export "$v=$val"
    done
    WAYLAND_DISPLAY=$(env_get "$n" WAYLAND_DISPLAY); WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-$(env_get "$b" WAYLAND_DISPLAY)}
    NIRI_SOCKET=$(env_get "$n" NIRI_SOCKET); NIRI_SOCKET=${NIRI_SOCKET:-$(env_get "$b" NIRI_SOCKET)}
    export WAYLAND_DISPLAY NIRI_SOCKET
}

cmd=${1:-status}
shift || true

case "$cmd" in
    call)
        sandbox_env
        exec quickshell ipc -p "$QML" call "$@"
        ;;
    restart)
        # Kill by pid (pkill -f would also match this script's own argv).
        qs_pid=$(pgrep -f "quickshell -p $QML" | head -1 || true)
        [[ -n "$qs_pid" ]] && kill "$qs_pid" 2>/dev/null || true
        sleep 0.5
        sandbox_env
        # Spawn inside the sandbox bus so the new instance is discoverable.
        setsid sh -c "exec quickshell -p '$QML' >> $SB/qs.log 2>&1" &
        echo "quickshell respawned"
        ;;
    status)
        echo "niri:     $(niri_pid || echo DOWN)"
        echo "shell:    $(pgrep -f "quickshell -p $QML" | head -1 || echo DOWN)"
        sandbox_env
        for i in $(seq 1 30); do
            out=$(quickshell ipc -p "$QML" call theming dir 2>/dev/null || true)
            case "$out" in *app-themes*) echo "ipc:      READY ($out)"; exit 0;; esac
            sleep 0.4
        done
        echo "ipc:      NOT READY"
        exit 1
        ;;
    shot)
        sandbox_env
        name=${1:-sandbox}
        mkdir -p "$SB/shots"
        out="$SB/shots/$name.png"
        rm -f "$SB"/shot-*.png
        niri msg action screenshot-screen
        sleep 1.5
        # niri writes to screenshot-path from its config
        latest=$(ls -t "$SB"/shot-*.png 2>/dev/null | head -1 || true)
        [[ -n "$latest" ]] && cp "$latest" "$out" && echo "saved $out" || echo "no shot produced (locked session? see README)" >&2
        ;;
    *)
        echo "usage: dev/sbx.sh {call|restart|status|shot} ..." >&2
        exit 2
        ;;
esac
