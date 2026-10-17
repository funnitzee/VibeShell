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
#   6. with --apps: wires kitty/GTK include lines and VS Code/spicetify theme
#      symlinks so external apps follow the VibeShell palette (backed up first)
#
# Every file it would overwrite is backed up first as <file>.bak.<timestamp>.

set -euo pipefail

REPO_URL="https://github.com/funnitzee/VibeShell.git"
PREFIX="${VIBESHELL_PREFIX:-$HOME/.local/share/vibeshell}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PACKAGES=(git niri quickshell ttf-jetbrains-mono-nerd brightnessctl)

ASSUME_YES=0
INSTALL_PACKAGES=1
PATCH_NIRI=0
PATCH_APPS=0

usage() {
    cat <<'EOF'
Usage: install.sh [options]

  -y, --yes          do not ask for confirmation
      --no-packages  skip the pacman step
      --niri         add `include "vibeshell.kdl"` to your niri config.kdl (backed up first)
      --apps         wire kitty/GTK includes + VS Code/spicetify theme symlinks (backed up first)
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

# ensure_line <file> <line>: create <file> if needed and append <line> once,
# backing the file up first when it already exists.
ensure_line() {
    local f=$1 line=$2
    if [[ -e $f ]] && grep -qxF "$line" "$f"; then
        log "$f already has the VibeShell line"
        return 0
    fi
    mkdir -p "$(dirname "$f")"
    [[ -e $f ]] && backup "$f"
    printf '\n%s\n' "$line" >>"$f"
    log "Added VibeShell line to $f"
}

# link_theme <link> <target>: point <link> at <target>, backing up any existing
# entry first. Used for apps that cannot include a file at runtime.
link_theme() {
    local link=$1 target=$2
    if [[ -L $link && "$(readlink "$link")" == "$target" ]]; then
        log "$link already points at $target"
        return 0
    fi
    if [[ -e $link || -L $link ]]; then
        backup "$link"
        rm -rf "$link"
    fi
    mkdir -p "$(dirname "$link")"
    ln -s "$target" "$link"
    log "Linked $link -> $target"
}

while (($#)); do
    case $1 in
    -y | --yes) ASSUME_YES=1 ;;
    --no-packages) INSTALL_PACKAGES=0 ;;
    --niri) PATCH_NIRI=1 ;;
    --apps) PATCH_APPS=1 ;;
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
    Mod+P hotkey-overlay-title="VibeShell dashboard" { spawn "quickshell" "ipc" "-p" "$SRC/shell" "call" "dashboard" "toggle"; }
    Mod+S hotkey-overlay-title="VibeShell quick settings" { spawn "quickshell" "ipc" "-p" "$SRC/shell" "call" "quick" "toggle"; }
    Mod+Shift+S hotkey-overlay-title="VibeShell settings" { spawn "quickshell" "ipc" "-p" "$SRC/shell" "call" "settings" "toggle"; }
    Mod+Alt+L hotkey-overlay-title="VibeShell lock" { spawn "quickshell" "ipc" "-p" "$SRC/shell" "call" "lock" "lock"; }
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

# 6. App theming: let external apps follow the VibeShell palette.
# The shell writes theme files under ~/.config/vibeshell/app-themes/<app>/.
# kitty and GTK get an include/import (live), VS Code and spicetify get a
# symlink into their own config (they cannot include a file at runtime).
THEME_DIR="$CONFIG_HOME/vibeshell/app-themes"
if ((PATCH_APPS)); then
    # kitty
    if [[ -d $CONFIG_HOME/kitty || -f $CONFIG_HOME/kitty/kitty.conf ]]; then
        ensure_line "$CONFIG_HOME/kitty/kitty.conf" "include $THEME_DIR/kitty/kitty-theme.conf"
    else
        warn "kitty config not found, skipping (run the shell once to generate themes)"
    fi

    # GTK 3 + GTK 4
    for gtk in gtk-3.0 gtk-4.0; do
        if [[ -d $CONFIG_HOME/$gtk ]]; then
            ensure_line "$CONFIG_HOME/$gtk/gtk.css" "@import url(\"$THEME_DIR/gtk/gtk.css\");"
        fi
    done

    # VS Code color theme extension
    if [[ -d $HOME/.vscode ]]; then
        link_theme "$HOME/.vscode/extensions/vibeshell-theme" "$THEME_DIR/vscode"
    else
        warn "VS Code (~/.vscode) not found, skipping"
    fi

    # spicetify
    if [[ -d $CONFIG_HOME/spicetify ]]; then
        link_theme "$CONFIG_HOME/spicetify/Themes/VibeShell" "$THEME_DIR/spicetify"
        if command -v spicetify >/dev/null; then
            spicetify config current_theme VibeShell >/dev/null 2>&1 && log "spicetify: current_theme -> VibeShell"
            command -v spotify >/dev/null && spicetify apply >/dev/null 2>&1 && log "spicetify: applied"
        fi
    else
        warn "spicetify config not found, skipping"
    fi

    log "App themes live in $THEME_DIR (regenerated on every palette change)."
else
    log "For external app theming (kitty/GTK/VS Code/spicetify), re-run with --apps."
fi

log "Done. To try it without restarting niri: quickshell -p $SRC/shell"