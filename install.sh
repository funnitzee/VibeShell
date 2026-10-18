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
PACKAGES=(git niri quickshell ttf-jetbrains-mono-nerd brightnessctl kitty swaybg)

ASSUME_YES=0
INSTALL_PACKAGES=1
PATCH_NIRI=0
PATCH_APPS=0
INSTALL_SDDM=0
SUPER_TAP=0
STRIP_PLYMOUTH=0

usage() {
    cat <<'EOF'
Usage: install.sh [options]

  -y, --yes          do not ask for confirmation
      --no-packages  skip the pacman step
      --niri         add `include "vibeshell.kdl"` to your niri config.kdl (backed up first)
      --apps         wire kitty/GTK includes + VS Code/spicetify theme symlinks (backed up first)
      --sddm         install the VibeShell SDDM theme and select it (backed up first, needs sudo)
      --super-tap    make a lone Super key open the palette (installs keyd, backed up first)
      --no-plymouth  remove plymouth and the silent boot (quiet/splash) from the kernel cmdline
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
    --sddm) INSTALL_SDDM=1 ;;
    --super-tap) SUPER_TAP=1 ;;
    --no-plymouth) STRIP_PLYMOUTH=1 ;;
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
EOF
    # Only add a bind when the same key is not already bound elsewhere in the
    # niri config (dms, config.kdl...): niri refuses to load a config with
    # duplicate keybinds, so adding ours blindly would break the session.
    bind_taken() {
        local key=$1 f esc
        esc=${key//+/\\+}
        while IFS= read -r f; do
            [[ $f == "$SNIPPET" ]] && continue
            grep -qE "^[[:space:]]*${esc}([[:space:]]|\{)" "$f" && return 0
        done < <(find "$NIRI_DIR" -type f -name '*.kdl' 2>/dev/null)
        return 1
    }
    add_bind() {
        local key=$1 rest=$2
        if bind_taken "$key"; then
            warn "Skipping $key in vibeshell.kdl: already bound elsewhere in $NIRI_DIR"
        else
            printf '    %s %s\n' "$key" "$rest"
        fi
    }
    ipc='spawn "quickshell" "ipc" "-p" "'"$SRC"'/shell" "call"'
    add_bind "Mod+Semicolon" "hotkey-overlay-title=\"VibeShell palette\" { $ipc \"palette\" \"toggle\"; }"
    # A lone Super key (keyd, see --super-tap) sends F15 and opens the palette.
    add_bind "F15" "hotkey-overlay-title=\"VibeShell palette\" { $ipc \"palette\" \"toggle\"; }"
    add_bind "Mod+P" "hotkey-overlay-title=\"VibeShell dashboard\" { $ipc \"dashboard\" \"toggle\"; }"
    add_bind "Mod+S" "hotkey-overlay-title=\"VibeShell quick settings\" { $ipc \"quick\" \"toggle\"; }"
    add_bind "Mod+Shift+S" "hotkey-overlay-title=\"VibeShell settings\" { $ipc \"settings\" \"toggle\"; }"
    add_bind "Mod+Alt+L" "hotkey-overlay-title=\"VibeShell lock\" { $ipc \"lock\" \"lock\"; }"
    add_bind "Mod+Return" 'hotkey-overlay-title="Terminal" { spawn "kitty"; }'
    add_bind "XF86AudioRaiseVolume" 'allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }'
    add_bind "XF86AudioLowerVolume" 'allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }'
    add_bind "XF86AudioMute" 'allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }'
    cat <<EOF
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
    if command -v kitty >/dev/null || [[ -d $CONFIG_HOME/kitty ]]; then
        ensure_line "$CONFIG_HOME/kitty/kitty.conf" "include $THEME_DIR/kitty/kitty-theme.conf"
    else
        warn "kitty not found, skipping (install kitty, then re-run with --apps)"
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

# 7. SDDM theme. Copies sddm/vibeshell to /usr/share/sddm/themes/vibeshell,
# colours it from the active palette and selects it in /etc/sddm.conf.d.
if ((INSTALL_SDDM)); then
    if [[ ! -d /usr/share/sddm ]]; then
        warn "SDDM not installed, skipping the theme."
    elif confirm "Install the VibeShell SDDM theme and set it as default?"; then
        # Active palette: name from settings.json, colours from palettes/<name>.json.
        pal=$(grep -o '"palette": *"[^"]*"' "$CONFIG_HOME/vibeshell/settings.json" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')
        pal=${pal:-monochrome}
        pal_file="$SRC/shell/palettes/$pal.json"
        json_get() { grep -o "\"$2\": *\"[^\"]*\"" "$1" 2>/dev/null | sed 's/.*"\(#[0-9a-fA-F]*\)".*/\1/'; }
        if [[ -f $pal_file ]]; then
            c_bg=$(json_get "$pal_file" bg)
            c_fg=$(json_get "$pal_file" fg)
            c_dim=$(json_get "$pal_file" dim)
            c_border=$(json_get "$pal_file" border)
            c_accent=$(json_get "$pal_file" accent)
            c_urgent=$(json_get "$pal_file" urgent)
        fi

        theme_tmp=$(mktemp -d)
        cp -r "$SRC/sddm/vibeshell/." "$theme_tmp/"
        # Prefer the live theme.conf the shell generates (matches the palette,
        # including custom palettes); fall back to the JSON above.
        if [[ -f $THEME_DIR/sddm/theme.conf ]]; then
            cp "$THEME_DIR/sddm/theme.conf" "$theme_tmp/theme.conf"
        else
            cat >"$theme_tmp/theme.conf" <<EOF
[General]
bg=${c_bg:-#0a0a0a}
fg=${c_fg:-#e8e8e8}
dim=${c_dim:-#8a8a8a}
border=${c_border:-#2e2e2e}
accent=${c_accent:-#ffffff}
urgent=${c_urgent:-#ffffff}
font=JetBrainsMono Nerd Font
EOF
        fi

        dest=/usr/share/sddm/themes/vibeshell
        if [[ -e $dest ]]; then
            sudo cp -a "$dest" "$dest.bak.$(date +%Y%m%d-%H%M%S)"
        fi
        sudo mkdir -p "$dest"
        sudo cp -a "$theme_tmp/." "$dest/"
        rm -rf "$theme_tmp"

        conf=/etc/sddm.conf.d/vibeshell.conf
        sudo mkdir -p /etc/sddm.conf.d
        if [[ -e $conf ]]; then
            sudo cp -a "$conf" "$conf.bak.$(date +%Y%m%d-%H%M%S)"
        fi
        printf '[Theme]\nCurrent=vibeshell\n' | sudo tee "$conf" >/dev/null
        log "SDDM theme installed ($pal palette) and selected in $conf"
    fi
else
    log "For a VibeShell SDDM theme, re-run with --sddm."
fi

# 8. Super tap: a lone Super key opens the palette while Super+key still works.
# keyd's overload(meta, f15) sends F15 on tap; niri binds F15 to the palette.
if ((SUPER_TAP)); then
    if ! command -v keyd >/dev/null; then
        warn "keyd is not installed."
        if confirm "Install keyd now? (pacman -S keyd)"; then
            sudo pacman -S --needed --noconfirm keyd
        else
            die "keyd is required for --super-tap."
        fi
    fi
    if [[ ! -f /etc/keyd/default.conf ]] || confirm "Overwrite /etc/keyd/default.conf with the Super-tap rule?"; then
        if [[ -f /etc/keyd/default.conf ]]; then
            sudo cp -a /etc/keyd/default.conf "/etc/keyd/default.conf.bak.$(date +%Y%m%d-%H%M%S)"
        fi
        sudo mkdir -p /etc/keyd
        sudo tee /etc/keyd/default.conf >/dev/null <<'EOF'
# Managed by the VibeShell installer: a lone Super key opens the palette.
# Super combined with another key keeps working normally.
[ids]
*

[main]
leftmeta = overload(meta, f15)
EOF
        sudo systemctl enable --now keyd 2>/dev/null || warn "Could not start keyd (run 'sudo systemctl enable --now keyd')."
        log "Super tap -> F15 configured (keyd)."
    fi
    log "The F15 -> palette bind lives in $SNIPPET (re-run with --niri to add it)."
else
    log "For Super-tap palette (a lone Super key), re-run with --super-tap."
fi

# 9. Remove plymouth and the silent boot.
if ((STRIP_PLYMOUTH)); then
    if ! pacman -Qq plymouth >/dev/null 2>&1 && [[ ! -f /etc/default/grub ]]; then
        log "No plymouth and no /etc/default/grub, nothing to strip."
    elif confirm "Remove plymouth and the silent boot (quiet/splash) from GRUB?"; then
        if [[ -f /etc/default/grub ]]; then
            backup_grub="/etc/default/grub.bak.$(date +%Y%m%d-%H%M%S)"
            sudo cp -a /etc/default/grub "$backup_grub"
            # Drop splash/quiet from the kernel command line and turn the boot
            # verbose again (loglevel 3/4 -> 6).
            sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)splash \?/\1/; s/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)quiet \?/\1/; s/loglevel=[0-5]/loglevel=6/' /etc/default/grub
            log "Backed up /etc/default/grub -> $backup_grub and dropped splash/quiet (loglevel=6)."
            if command -v grub-mkconfig >/dev/null; then
                sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null && log "Regenerated /boot/grub/grub.cfg."
            fi
        fi
        # Remove the plymouth mkinitcpio hook so the boot stays verbose.
        if [[ -f /etc/mkinitcpio.conf ]] && grep -q 'plymouth' /etc/mkinitcpio.conf; then
            backup_mk="/etc/mkinitcpio.conf.bak.$(date +%Y%m%d-%H%M%S)"
            sudo cp -a /etc/mkinitcpio.conf "$backup_mk"
            sudo sed -i 's/ plymouth//g' /etc/mkinitcpio.conf
            log "Backed up /etc/mkinitcpio.conf -> $backup_mk and removed the plymouth hook."
            if command -v mkinitcpio >/dev/null; then
                sudo mkinitcpio -P >/dev/null && log "Rebuilt initramfs."
            fi
        fi
        if pacman -Qq plymouth >/dev/null 2>&1; then
            if confirm "Also remove the plymouth package?"; then
                sudo pacman -Rns --noconfirm plymouth
            fi
        fi
    fi
else
    log "To remove plymouth / the silent boot, re-run with --no-plymouth."
fi

log "Done. To try it without restarting niri: quickshell -p $SRC/shell"
