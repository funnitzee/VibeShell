#!/usr/bin/env bash
# VibeShell installer for Arch / CachyOS.
#
# Recommended (download, read, run):
#   curl -fsSL https://raw.githubusercontent.com/funnitzee/VibeShell/main/install.sh -o install.sh
#   less install.sh
#   bash install.sh
#
# One-liner (you trust this repo):
#   curl -fsSL https://raw.githubusercontent.com/funnitzee/VibeShell/main/install.sh | bash
#
# What it does:
#   1. installs packages with pacman (asks first)
#   2. fetches the repo to ~/.local/share/vibeshell (or uses the local checkout it runs from)
#   3. creates ~/.config/vibeshell/settings.json if missing (never overwrites it)
#   4. writes ~/.config/niri/vibeshell.kdl that starts the shell with niri
#   5. with --niri: adds `include "vibeshell.kdl"` to your niri config.kdl
#
# Every file it would overwrite is backed up first as <file>.bak.<timestamp>.

set -euo pipefail

REPO_URL="https://github.com/funnitzee/VibeShell.git"
PREFIX="${VIBESHELL_PREFIX:-$HOME/.local/share/vibeshell}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PACKAGES=(git niri quickshell ttf-jetbrains-mono-nerd)

ASSUME_YES=0
INSTALL_PACKAGES=1
PATCH_NIRI=0

usage() {
    cat <<'EOF'
Usage: install.sh [options]

  -y, --yes          do not ask for confirmation
      --no-packages  skip the pacman step
      --niri         add `include "vibeshell.kdl"` to your niri config.kdl (backed up first)
  -h, --help         show this help
EOF
}

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die() {
    printf '\033[1;31m==>\033[0m %s\n' "$*" >&2
    exit 1
}

confirm() {
    ((ASSUME_YES)) && return 0
    local ans
    # Read from the terminal so this also works when the script is piped into bash.
    read -r -p "$1 [y/N] " ans </dev/tty || return 1
    [[ $ans == [yY]* ]]
}

# backup <file>: copy it to <file>.bak.<timestamp> if it exists.
backup() {
    local f=$1 b
    [[ -e $f ]] || return 0
    b="$f.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a "$f" "$b"
    log "Backed up $f -> $b"
}

while (($#)); do
    case $1 in
    -y | --yes) ASSUME_YES=1 ;;
    --no-packages) INSTALL_PACKAGES=0 ;;
    --niri) PATCH_NIRI=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        die "Unknown option: $1"
        ;;
    esac
    shift
done

[[ $EUID -ne 0 ]] || die "Do not run this as root."

# 1. Packages
if ((INSTALL_PACKAGES)); then
    command -v pacman >/dev/null || die "pacman not found. This installer targets Arch / CachyOS."
    log "Packages: ${PACKAGES[*]}"
    if confirm "Install them with 'sudo pacman -S --needed'?"; then
        sudo pacman -S --needed "${PACKAGES[@]}"
    else
        warn "Skipping packages. The shell will not start without quickshell and niri."
    fi
fi

# 2. Source: use the local checkout if we run from one, otherwise clone.
# When piped into bash (curl | bash) BASH_SOURCE is empty, so we always clone then.
SCRIPT_DIR=""
if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -n $SCRIPT_DIR && -f $SCRIPT_DIR/shell/shell.qml ]]; then
    SRC="$SCRIPT_DIR"
    log "Using local checkout: $SRC"
else
    command -v git >/dev/null || die "git is required to fetch VibeShell."
    if [[ -d $PREFIX/.git ]]; then
        log "Updating $PREFIX"
        git -C "$PREFIX" pull --ff-only
    else
        log "Cloning into $PREFIX"
        mkdir -p "$(dirname "$PREFIX")"
        git clone --depth 1 "$REPO_URL" "$PREFIX"
    fi
    SRC="$PREFIX"
fi

# 3. User settings (never overwritten)
mkdir -p "$CONFIG_HOME/vibeshell"
if [[ ! -e $CONFIG_HOME/vibeshell/settings.json ]]; then
    echo '{}' >"$CONFIG_HOME/vibeshell/settings.json"
    log "Created $CONFIG_HOME/vibeshell/settings.json (empty: shipped defaults apply)"
fi

# 4. niri snippet that starts the shell
NIRI_DIR="$CONFIG_HOME/niri"
SNIPPET="$NIRI_DIR/vibeshell.kdl"
mkdir -p "$NIRI_DIR"
SNIPPET_BODY=$(
    cat <<EOF
// Managed by the VibeShell installer: re-running it overwrites this file.
spawn-at-startup "quickshell" "-p" "$SRC/shell"

binds {
    Mod+Semicolon hotkey-overlay-title="VibeShell palette" { spawn "quickshell" "ipc" "-p" "$SRC/shell" "call" "palette" "toggle"; }
    XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
    XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
}
EOF
)
if [[ -f $SNIPPET ]] && [[ "$(cat "$SNIPPET")" == "$SNIPPET_BODY" ]]; then
    log "$SNIPPET is up to date"
else
    backup "$SNIPPET"
    printf '%s\n' "$SNIPPET_BODY" >"$SNIPPET"
    log "Wrote $SNIPPET"
fi

# 5. Hook the snippet into the niri config
CFG="$NIRI_DIR/config.kdl"
INCLUDE='include "vibeshell.kdl"'
if ((PATCH_NIRI)); then
    if [[ ! -f $CFG ]]; then
        warn "No $CFG yet. Start niri once to generate it, then re-run with --niri."
    elif grep -qxF "$INCLUDE" "$CFG"; then
        log "$CFG already includes vibeshell.kdl"
    else
        backup "$CFG"
        printf '\n%s\n' "$INCLUDE" >>"$CFG"
        log "Added $INCLUDE to $CFG"
    fi
else
    log "To start VibeShell with niri, add this line to $CFG (or re-run with --niri):"
    printf '    %s\n' "$INCLUDE"
fi

log "Done. To try it without restarting niri: quickshell -p $SRC/shell"
