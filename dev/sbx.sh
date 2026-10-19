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

# quickshell inherits the nested niri's *own* Wayland socket (wayland-2, ...),
# not niri's inherited one (wayland-1). Read env off the shell process, falling
# back to niri's, so IPC targets the display the instance actually lives on.
sandbox_env() {
    local pid qs; qs=$(pgrep -f "quickshell -p $QML" | head -1 || true)
    pid=${qs:-$(niri_pid)}
    [[ -n "$pid" ]] || { echo "sandbox not running" >&2; return 1; }
    local env; env=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null)
    DBUS_SESSION_BUS_ADDRESS=$(printf '%s\n' "$env" | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
    WAYLAND_DISPLAY=$(printf '%s\n' "$env" | sed -n 's/^WAYLAND_DISPLAY=//p')
    NIRI_SOCKET=$(printf '%s\n' "$env" | sed -n 's/^NIRI_SOCKET=//p')
    export DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY NIRI_SOCKET
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
