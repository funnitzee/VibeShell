#!/usr/bin/env bash
# Smoke tests for VibeShell: runs the shell in an isolated nested-niri sandbox
# and drives it over IPC, asserting on the palette commands, the panels and a
# handful of services. The shell is copied to the sandbox so the IPC socket
# never clashes with a running dev sandbox (dev/run-nested.sh).
#
# Optional tools (brightnessctl, gammastep, powerprofilesctl, grim, slurp,
# swappy, cliphist, wl-copy, wl-paste) are faked, so everything can be checked
# on any machine.
#
# Needs a graphical session (WAYLAND_DISPLAY) plus niri, quickshell and
# dbus-run-session. Usage: dev/test.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
SB=${VIBESHELL_SANDBOX:-/tmp/vibeshell-test}
SHELL="$SB/shell/shell.qml"
QML_ORIGIN="$REPO/shell"

if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    echo "no WAYLAND_DISPLAY - run this from a graphical session" >&2
    exit 2
fi
for b in niri quickshell dbus-run-session; do
    command -v "$b" >/dev/null || { echo "missing: $b" >&2; exit 2; }
done

pass=0 fail=0
ok() { printf '  \033[32mok\033[0m    %s\n' "$1"; pass=$((pass + 1)); }
bad() {
    printf '  \033[31mFAIL\033[0m  %s\n' "$1"; shift
    for l in "$@"; do printf '        %s\n' "$l"; done
    fail=$((fail + 1))
}
check() { # desc substring actual
    if [[ "$3" == *"$2"* ]]; then ok "$1"; else bad "$1" "want: $2" "got:  $3"; fi
}
pal() { quickshell ipc -p "$SHELL" call palette run "$1" 2>&1; }
call() { quickshell ipc -p "$SHELL" call "$@" 2>&1; }

cleanup() {
    if [[ -n ${NIRI_PID:-} ]]; then
        kill -TERM -- "-$NIRI_PID" 2>/dev/null || kill "$NIRI_PID" 2>/dev/null
    fi
    pkill -f "niri -c $SB/niri.kdl" 2>/dev/null
    pkill -f "quickshell -p $SHELL" 2>/dev/null
    return 0
}
trap cleanup EXIT

# --- isolated sandbox ---------------------------------------------------------
rm -rf "$SB"
mkdir -p "$SB"/{config/vibeshell/commands,cache,state,data,home,bin}
cp -r "$QML_ORIGIN" "$SB/shell"

printf '{ "stats": { "interval": 500 } }\n' >"$SB/config/vibeshell/settings.json"
cat >"$SB/config/vibeshell/commands/hello.sh" <<'EOS'
#!/usr/bin/env bash
# desc: test plugin
echo "$*" >"$HOME/plugin-ran"
EOS
chmod +x "$SB/config/vibeshell/commands/hello.sh"

# fake tools (same idea as dev/screenshots.sh)
cat >"$SB/bin/brightnessctl" <<'EOS'
#!/usr/bin/env bash
# stateful fake so set/get stay consistent between the shell's polls
state="$HOME/.brightness"
max=1000
cur=$(cat "$state" 2>/dev/null || echo 650)
case "$1" in
  get) echo "$cur" ;;
  max) echo "$max" ;;
  set)
    case "$2" in
      *%+) pct="${2%\%+}"; cur=$((cur + max * pct / 100)) ;;
      *%-) pct="${2%\%-}"; cur=$((cur - max * pct / 100)) ;;
      *%) pct="${2%\%}"; cur=$((max * pct / 100)) ;;
      *) cur="$2" ;;
    esac
    if ((cur < 0)); then cur=0; fi
    if ((cur > max)); then cur=$max; fi
    echo "$cur" >"$state"
    ;;
esac
EOS
cat >"$SB/bin/gammastep" <<'EOS'
#!/usr/bin/env bash
echo "gammastep $*" >>"$HOME/night.log"
exit 0
EOS
cat >"$SB/bin/grim" <<'EOS'
#!/usr/bin/env bash
: >"${@: -1}"
EOS
cat >"$SB/bin/slurp" <<'EOS'
#!/usr/bin/env bash
echo "0,0 10x10"
EOS
cat >"$SB/bin/swappy" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
cat >"$SB/bin/cliphist" <<'EOS'
#!/usr/bin/env bash
case "$1" in
  list) printf '42\thello from clipboard\n' ;;
  *) exit 0 ;;
esac
EOS
cat >"$SB/bin/wl-copy" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
cat >"$SB/bin/wl-paste" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
cat >"$SB/bin/powerprofilesctl" <<'EOS'
#!/usr/bin/env bash
case "$1" in
  list) printf '  performance:\n    Driver: placeholder\n  power-saver:\n    Driver: placeholder\n\n* balanced:\n    Driver: placeholder\n' ;;
  set) echo "$2" >"$HOME/ppd" ;;
  *) exit 0 ;;
esac
EOS
chmod +x "$SB"/bin/*

# @REPO@ points at the *copy* so the test shell gets its own IPC socket and does
# not clash with a running dev sandbox using the original path.
sed "s|@REPO@|$SB|g;s|@SB@|$SB|g" "$REPO/dev/niri-dev.kdl" >"$SB/niri.kdl"

export XDG_CONFIG_HOME=$SB/config
export XDG_CACHE_HOME=$SB/cache
export XDG_STATE_HOME=$SB/state
export XDG_DATA_HOME=$SB/data
export HOME=$SB/home
export VIBESHELL_CONFIG_DIR=$SB/config/vibeshell
export PATH="$SB/bin:$PATH"

# Clear leftovers from a previous run so its display/bus are actually free.
pkill -f "niri -c $SB/niri.kdl" 2>/dev/null
pkill -f "quickshell -p $SB/shell/shell.qml" 2>/dev/null
for _ in $(seq 40); do
    pgrep -f "quickshell -p $SB/shell/shell.qml" >/dev/null || break
    sleep 0.25
done

niri validate -c "$SB/niri.kdl" >/dev/null || { echo "invalid niri config" >&2; exit 2; }

# The real session exports NIRI_SOCKET; drop it so the nested niri names its own
# socket freshly instead of colliding with the parent's.
unset NIRI_SOCKET
setsid dbus-run-session -- niri -c "$SB/niri.kdl" >"$SB/niri.log" 2>&1 </dev/null &
NIRI_PID=$!

# Quickshell IPC is scoped to the compositor's display and talks over the session
# bus, so read both straight from the shell process niri spawned - no guessing at
# the socket name (its wayland-N is picked at runtime).
qp=""
for _ in $(seq 80); do
    qp=$(pgrep -f "quickshell -p $SHELL" | head -1)
    [[ -n $qp ]] && break
    sleep 0.25
done
if [[ -z $qp ]]; then
    echo "shell did not start - see $SB/niri.log and $SB/qs.log" >&2
    exit 1
fi
venv=$(tr '\0' '\n' <"/proc/$qp/environ")
DBUS_SESSION_BUS_ADDRESS=$(sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p' <<<"$venv")
WAYLAND_DISPLAY=$(sed -n 's/^WAYLAND_DISPLAY=//p' <<<"$venv")
NIRI_SOCKET=$(sed -n 's/^NIRI_SOCKET=//p' <<<"$venv")
export DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY NIRI_SOCKET

# Wait until the shell answers on IPC.
ready=0
for _ in $(seq 60); do
    if quickshell ipc -p "$SHELL" call palette run ":help" >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 0.25
done
if [[ $ready -ne 1 ]]; then
    echo "shell did not come up - see $SB/niri.log and $SB/qs.log" >&2
    exit 1
fi

echo "palette"
check ":help lists commands" "list:" "$(pal ':help')"
pal ':hello world' >/dev/null 2>&1
sleep 0.3
check "plugin runs" "world" "$(cat "$SB/home/plugin-ran" 2>/dev/null)"
check ":calc adds" "= 4" "$(pal ':calc 2+2')"
check ":calc precedence" "= 20" "$(pal ':calc (2+3)*4')"
check ":calc rejects junk" "cannot parse" "$(pal ':calc nope')"
check ":theme lists palettes" "palette:" "$(pal ':theme')"
check ":set changes a value" "ui.scale = 1.2" "$(pal ':set ui.scale 1.2')"
check ":night toggles on" "night light on" "$(pal ':night on')"
check ":night sets kelvin" "3000K" "$(pal ':night 3000')"
check ":power lists profiles" "list:" "$(pal ':power profile')"
check ":power sets a profile" "performance" "$(pal ':power profile performance')"
check ":notify dnd toggles" "do-not-disturb" "$(pal ':notify dnd')"
check ":notify lists" "list:" "$(pal ':notify')"
check ":shot lists modes" "list:" "$(pal ':shot')"
check ":clip lists history" "list:" "$(pal ':clip')"
check ":emoji lists" "list:" "$(pal ':emoji')"

echo "osd"
check "brightness ipc set" "40" "$(call brightness set 40)"
check "brightness ipc up" "45" "$(call brightness up)"
check "brightness ipc down" "40" "$(call brightness down)"

echo "panels"
for p in quick settings keys dashboard; do
    out=$(call "$p" open)
    [[ -z "$out" ]] && ok "open $p" || bad "open $p" "unexpected: $out"
    call "$p" hide >/dev/null 2>&1
done

echo "services"
check "night light applied" "gammastep" "$(cat "$SB/home/night.log" 2>/dev/null)"
check "power profile active" "performance" "$(cat "$SB/home/ppd" 2>/dev/null)"
scale=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["ui"]["scale"])' "$SB/config/vibeshell/settings.json" 2>&1)
check "settings written" "1.2" "$scale"

echo
printf 'passed %d, failed %d\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
