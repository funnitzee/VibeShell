#!/usr/bin/env bash
# VibeShell interactive installer for Arch / CachyOS
# Guided TUI by default; flags kept for automation/CI

set -euo pipefail

REPO_URL="https://github.com/funnitzee/VibeShell.git"
PREFIX="${VIBESHELL_PREFIX:-$HOME/.local/share/vibeshell}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Base minimal packages
BASE_PKGS=(git niri quickshell ttf-jetbrains-mono-nerd kitty brightnessctl swaybg wireplumber networkmanager bluez upower matugen)
BALANCED_PKGS=(grim slurp wl-clipboard cliphist libnotify gammastep power-profiles-daemon swappy)
# Note: display managers and keyd are only installed when their flag is used
# (--sddm / --greeter / --super-tap), never just because a profile was picked.
# The shell ships its own polkit agent, so no separate agent package is needed.

ASSUME_YES=0
DRY_RUN=0
GUIDED=1
PROFILE="guided"
DO_CUSTOM=0
PATCH_NIRI=1
PATCH_APPS=1
INSTALL_SDDM=0
INSTALL_GREETER=0
SUPER_TAP=0
STRIP_PLYMOUTH=0
INSTALL_PKGS=1

usage() {
  cat <<'EOF'
Usage: install.sh [options]

  -y, --yes        non-interactive (needs profile or flags)
  -d, --dry-run    show what would be done
  --guided         force guided TUI (default if TTY)
  --profile P      minimal|balanced|full|custom
  --niri           include vibeshell.kdl
  --no-niri        skip
  --apps           wire kitty/GTK/VSCode/spicetify
  --no-apps        skip
  --sddm           install SDDM theme+config
  --greeter        setup greetd greeter
  --super-tap      enable Super-tap (keyd + F15)
  --no-pkgs        skip the pacman step (packages already installed)
  --no-plymouth    strip plymouth/silent boot
  -h, --help       show help
EOF
}

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

confirm() {
  ((ASSUME_YES)) && return 0
  local ans
  if [ -t 0 ] && [ -t 1 ]; then
    read -r -p "$1 [y/N] " ans </dev/tty || read -r ans || return 1
  else
    read -r ans || return 1
  fi
  [[ $ans == [yY]* ]]
}

backup() {
  local f=$1 b
  [[ -e $f ]] || return 0
  b="$f.bak.$(date +%Y%m%d-%H%M%S)"
  ((DRY_RUN)) && { log "[DRY] backup $f -> $b"; return 0; }
  cp -a "$f" "$b"
  log "Backed up $f -> $b"
}

ensure_line() {
  local f=$1 line=$2
  if [[ -e $f ]] && grep -qxF "$line" "$f"; then
    log "$f already has line"
    return 0
  fi
  ((DRY_RUN)) && { log "[DRY] ensure_line $f: $line"; return 0; }
  mkdir -p "$(dirname "$f")"
  [[ -e $f ]] && backup "$f"
  printf '\n%s\n' "$line" >>"$f"
  log "Added to $f"
}

link_theme() {
  local link=$1 target=$2
  if [[ -L $link && "$(readlink "$link")" == "$target" ]]; then
    log "$link ok"
    return 0
  fi
  ((DRY_RUN)) && { log "[DRY] link $link -> $target"; return 0; }
  if [[ -e $link || -L $link ]]; then backup "$link"; rm -rf "$link"; fi
  mkdir -p "$(dirname "$link")"; ln -s "$target" "$link"; log "Linked $link"
}

while (($#)); do
  case $1 in
    -y|--yes) ASSUME_YES=1; GUIDED=0 ;;
    -d|--dry-run) DRY_RUN=1 ;;
    --guided) GUIDED=1 ;;
    --profile)
      shift; PROFILE=$1; GUIDED=0
      [[ $PROFILE =~ ^(minimal|balanced|full|custom)$ ]] || die "bad profile: $PROFILE"
      ;;
    --niri) PATCH_NIRI=1 ;;
    --no-niri) PATCH_NIRI=0 ;;
    --apps) PATCH_APPS=1 ;;
    --no-apps) PATCH_APPS=0 ;;
    --sddm) INSTALL_SDDM=1 ;;
    --greeter) INSTALL_GREETER=1 ;;
    --super-tap) SUPER_TAP=1 ;;
    --no-pkgs) INSTALL_PKGS=0 ;;
    --no-plymouth) STRIP_PLYMOUTH=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown: $1" ;;
  esac
  shift
done

if [[ -t 1 && $GUIDED -eq 1 ]]; then
  PROFILE="guided"
fi

# Pre-flight
[[ $EUID -ne 0 ]] || die "Do not run as root."
command -v pacman >/dev/null || die "pacman required (Arch/CachyOS)."

# Guided
if [[ $PROFILE == "guided" ]]; then
  echo "VibeShell interactive installer"
  echo "================================"
  if [ -t 0 ] && [ -t 1 ] && confirm "Show full summary before changes? (recommended)"; then :; fi
  if ! has whiptail && ! has gum; then
    warn "No whiptail/gum - using simple prompts"
  fi
  # simple menu fallback
  PS3="Select profile: "
  select p in minimal balanced full custom quit; do
    case $p in
      minimal|balanced|full|custom) PROFILE=$p; break ;;
      quit) exit 0 ;;
    esac
  done
  case $PROFILE in
    minimal)
      PATCH_NIRI=1; PATCH_APPS=1; INSTALL_SDDM=0; INSTALL_GREETER=0; SUPER_TAP=0 ;;
    balanced)
      PATCH_NIRI=1; PATCH_APPS=1; INSTALL_SDDM=0; INSTALL_GREETER=0; SUPER_TAP=0 ;;
    full)
      PATCH_NIRI=1; PATCH_APPS=1; INSTALL_SDDM=0; INSTALL_GREETER=0; SUPER_TAP=0
      echo "Login method:"
      PS3="Choose: "
      select lm in "Install SDDM and its VibeShell theme" "Switch to greetd + VibeShell greeter" skip; do
        case $lm in
          *SDDM*) INSTALL_SDDM=1; INSTALL_GREETER=0; break ;;
          *greetd*) INSTALL_GREETER=1; INSTALL_SDDM=0; break ;;
          skip) break ;;
        esac
      done
      if confirm "Enable Super-tap (lone Super -> palette)?"; then SUPER_TAP=1; fi ;;
    custom)
      DO_CUSTOM=1 ;;
  esac
fi

# apply profile packages
PKGS=("${BASE_PKGS[@]}")
case $PROFILE in
  balanced|full) PKGS+=("${BALANCED_PKGS[@]}") ;;
  custom) : ;;
esac

# custom checkboxes simple
if ((DO_CUSTOM)); then
  echo "Custom selection:"
  confirm "Install packages?"
  confirm "Wire niri include?" && PATCH_NIRI=1 || PATCH_NIRI=0
  confirm "Wire app theming (kitty/GTK/VSCode/spicetify)?" && PATCH_APPS=1 || PATCH_APPS=0
  confirm "Add balanced utils (grim/slurp/wl-clipboard/cliphist/libnotify)?" && PKGS+=("${BALANCED_PKGS[@]}")
  if confirm "SDDM theme only?"; then INSTALL_SDDM=1; fi
  if confirm "Setup greetd greeter (replaces DM)?"; then INSTALL_GREETER=1; fi
  if confirm "Enable Super-tap?"; then SUPER_TAP=1; PKGS+=(keyd); fi
  if confirm "Strip plymouth/silent boot?"; then STRIP_PLYMOUTH=1; fi
fi

# ensure keyd present if supertap
((SUPER_TAP)) && PKGS+=(keyd)
((INSTALL_SDDM)) && PKGS+=(sddm)
((INSTALL_GREETER)) && PKGS+=(greetd)

# summary
log "Profile: $PROFILE"
log "Packages: ${PKGS[*]}"
log "patch_niri=$PATCH_NIRI patch_apps=$PATCH_APPS sddm=$INSTALL_SDDM greetd=$INSTALL_GREETER supertap=$SUPER_TAP plymouth_strip=$STRIP_PLYMOUTH"
((DRY_RUN)) && { warn "DRY RUN - no changes"; exit 0; }
if ! confirm "Proceed?"; then exit 0; fi

# Packages
if (( ${#PKGS[@]} )) && ((INSTALL_PKGS)); then
  log "Installing: ${PKGS[*]}"
  if confirm "Run 'sudo pacman -S --needed'?"; then
    ((DRY_RUN)) || sudo pacman -S --needed "${PKGS[@]}"
  fi
elif (( ${#PKGS[@]} )); then
  log "skipping pacman (--no-pkgs)"
fi

# Source
SCRIPT_DIR=""
if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -n $SCRIPT_DIR && -f $SCRIPT_DIR/shell/shell.qml ]]; then
  SRC="$SCRIPT_DIR"; log "Using local: $SRC"
else
  has git || die "git required"
  if [[ -d $PREFIX/.git ]]; then
    log "Updating $PREFIX"; ((DRY_RUN)) || git -C "$PREFIX" pull --ff-only
  else
    log "Cloning to $PREFIX"; ((DRY_RUN)) || { mkdir -p "$(dirname "$PREFIX")"; git clone --depth 1 "$REPO_URL" "$PREFIX"; }
  fi
  SRC="$PREFIX"
fi

# Settings
((DRY_RUN)) || { mkdir -p "$CONFIG_HOME/vibeshell"; [[ -e $CONFIG_HOME/vibeshell/settings.json ]] || echo '{}' >"$CONFIG_HOME/vibeshell/settings.json"; log "settings ok"; }

# User command plugins: any executable here shows up in the palette as :name.
COMMANDS_DIR="$CONFIG_HOME/vibeshell/commands"
if [[ ! -d $COMMANDS_DIR ]]; then
  ((DRY_RUN)) || mkdir -p "$COMMANDS_DIR"
  log "created $COMMANDS_DIR"
fi
if [[ -z $(find "$COMMANDS_DIR" -maxdepth 1 -type f 2>/dev/null) ]]; then
  ((DRY_RUN)) || {
    cat >"$COMMANDS_DIR/hello.sh" <<'EOF'
#!/usr/bin/env bash
# desc: example plugin - edit or delete me
notify-send -a vibeshell "vibeshell plugin" "hello from :hello"
EOF
    chmod +x "$COMMANDS_DIR/hello.sh"
  }
  log "wrote example plugin $COMMANDS_DIR/hello.sh"
fi

# CLI wrapper (~/.local/bin/vibeshell)
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
if [[ -f $SRC/bin/vibeshell ]]; then
  ((DRY_RUN)) || { mkdir -p "$BIN_DIR"; install -m755 "$SRC/bin/vibeshell" "$BIN_DIR/vibeshell"; }
  log "installed $BIN_DIR/vibeshell"
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not on PATH - add it to use 'vibeshell'" ;; esac
fi

# niri snippet
NIRI_DIR="$CONFIG_HOME/niri"
SNIPPET="$NIRI_DIR/vibeshell.kdl"
mkdir -p "$NIRI_DIR"
SNIPPET_BODY=$(
  cat <<EOF
// Managed by VibeShell installer
spawn-at-startup "quickshell" "-p" "$SRC/shell"

binds {
EOF
  # Only files actually pulled in by config.kdl can really block a bind:
  # leftover directories (or backups) must not make us skip our own keys.
  KDL_ACTIVE=()
  collect_kdl() {
    local f=$1 line rel
    [[ -f $f ]] || return 0
    KDL_ACTIVE+=("$f")
    while IFS= read -r line; do
      rel=${line#*\"}; rel=${rel%%\"*}
      [[ -n $rel ]] || continue
      collect_kdl "$NIRI_DIR/$rel"
    done < <(grep -E '^[[:space:]]*include' "$f" 2>/dev/null || true)
  }
  collect_kdl "$NIRI_DIR/config.kdl"
  bind_taken() {
    local key=$1 f esc; esc=${key//+/\\+}
    for f in "${KDL_ACTIVE[@]}"; do
      [[ $f == "$SNIPPET" ]] && continue
      grep -qE "^[[:space:]]*${esc}([[:space:]]|\{)" "$f" 2>/dev/null && return 0
    done
    return 1
  }
  add_bind() {
    local key=$1 rest=$2
    if bind_taken "$key"; then warn "skip $key (taken)"; else printf '    %s %s\n' "$key" "$rest"; fi
  }
  ipc='spawn "quickshell" "ipc" "-p" "'"$SRC"'/shell" "call"'
  add_bind "Mod+Semicolon" "hotkey-overlay-title=\"VibeShell palette\" { $ipc \"palette\" \"toggle\"; }"
  add_bind "F15" "hotkey-overlay-title=\"VibeShell palette\" { $ipc \"palette\" \"toggle\"; }"
  add_bind "Mod+P" "hotkey-overlay-title=\"VibeShell dashboard\" { $ipc \"dashboard\" \"toggle\"; }"
  add_bind "Mod+S" "hotkey-overlay-title=\"VibeShell quick settings\" { $ipc \"quick\" \"toggle\"; }"
  add_bind "Mod+Shift+S" "hotkey-overlay-title=\"VibeShell settings\" { $ipc \"settings\" \"toggle\"; }"
  add_bind "Mod+Alt+L" "hotkey-overlay-title=\"VibeShell lock\" { $ipc \"lock\" \"lock\"; }"
  add_bind "Mod+Slash" "hotkey-overlay-title=\"VibeShell keybinds\" { $ipc \"keys\" \"toggle\"; }"
  add_bind "Mod+Return" 'hotkey-overlay-title="Terminal" { spawn "kitty"; }'
  add_bind "XF86AudioRaiseVolume" 'allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }'
  add_bind "XF86AudioLowerVolume" 'allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }'
  add_bind "XF86AudioMute" 'allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }'
  add_bind "XF86AudioPlay" "allow-when-locked=true { $ipc \"media\" \"toggle\"; }"
  add_bind "XF86AudioNext" "allow-when-locked=true { $ipc \"media\" \"next\"; }"
  add_bind "XF86AudioPrev" "allow-when-locked=true { $ipc \"media\" \"previous\"; }"
  add_bind "Print" "hotkey-overlay-title=\"Screenshot\" { $ipc \"shot\" \"full\"; }"
  add_bind "Shift+Print" "hotkey-overlay-title=\"Screenshot region\" { $ipc \"shot\" \"region\"; }"
  add_bind "XF86MonBrightnessUp" "allow-when-locked=true { $ipc \"brightness\" \"up\"; }"
  add_bind "XF86MonBrightnessDown" "allow-when-locked=true { $ipc \"brightness\" \"down\"; }"
  cat <<EOF
}
EOF
)
if [[ ! -f $SNIPPET ]] || [[ "$(cat "$SNIPPET")" != "$SNIPPET_BODY" ]]; then
  backup "$SNIPPET"
  ((DRY_RUN)) || printf '%s\n' "$SNIPPET_BODY" >"$SNIPPET"
  log "wrote $SNIPPET"
fi
if ((PATCH_NIRI)); then
  CFG="$NIRI_DIR/config.kdl"; INC='include "vibeshell.kdl"'
  if [[ ! -f $CFG ]]; then warn "no $CFG - add $INC later"; else
    if ! grep -qxF "$INC" "$CFG"; then backup "$CFG"; ((DRY_RUN)) || printf '\n%s\n' "$INC" >>"$CFG"; log "added include"; else log "include exists"; fi
  fi
fi

# apps
THEME_DIR="$CONFIG_HOME/vibeshell/app-themes"
if ((PATCH_APPS)); then
  if has kitty || [[ -d $CONFIG_HOME/kitty ]]; then ensure_line "$CONFIG_HOME/kitty/kitty.conf" "include $THEME_DIR/kitty/kitty-theme.conf"; fi
  for gtk in gtk-3.0 gtk-4.0; do [[ -d $CONFIG_HOME/$gtk ]] && ensure_line "$CONFIG_HOME/$gtk/gtk.css" "@import url(\"$THEME_DIR/gtk/gtk.css\");"; done
  [[ -d $HOME/.vscode ]] && link_theme "$HOME/.vscode/extensions/vibeshell-theme" "$THEME_DIR/vscode"
  if [[ -d $CONFIG_HOME/spicetify ]]; then
    link_theme "$CONFIG_HOME/spicetify/Themes/VibeShell" "$THEME_DIR/spicetify"
    if ! ((DRY_RUN)) && has spicetify; then spicetify config current_theme VibeShell >/dev/null 2>&1 || true; has spotify && spicetify apply >/dev/null 2>&1 || true; fi
  fi
  log "app theming wired"
fi

# sddm
if ((INSTALL_SDDM)); then
  if [[ -d /usr/share/sddm ]]; then
    pal=$(grep -o '"palette": *"[^"]*"' "$CONFIG_HOME/vibeshell/settings.json" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/') || true
    pal=${pal:-monochrome}; pal_file="$SRC/shell/palettes/$pal.json"
    c_bg="#0a0a0a"; c_fg="#e8e8e8"; c_dim="#8a8a8a"; c_border="#2e2e2e"; c_accent="#ffffff"; c_urgent="#ffffff"
    if [[ -f $pal_file ]]; then
      json_get(){ grep -o "\"$2\": *\"[^\"]*\"" "$1" 2>/dev/null | sed 's/.*"\(#[0-9a-fA-F]*\)".*/\1/' || true; }
      c_bg=$(json_get "$pal_file" bg); c_fg=$(json_get "$pal_file" fg); c_dim=$(json_get "$pal_file" dim); c_border=$(json_get "$pal_file" border); c_accent=$(json_get "$pal_file" accent); c_urgent=$(json_get "$pal_file" urgent)
    fi
    theme_tmp=$(mktemp -d)
    cp -r "$SRC/sddm/vibeshell/." "$theme_tmp/"
    if [[ -f $THEME_DIR/sddm/theme.conf ]]; then cp "$THEME_DIR/sddm/theme.conf" "$theme_tmp/theme.conf"
    else cat >"$theme_tmp/theme.conf" <<EOF
[General]
bg=${c_bg}
fg=${c_fg}
dim=${c_dim}
border=${c_border}
accent=${c_accent}
urgent=${c_urgent}
font=JetBrainsMono Nerd Font
EOF
    fi
    dest=/usr/share/sddm/themes/vibeshell
    ((DRY_RUN)) || { [[ -e $dest ]] && sudo cp -a "$dest" "$dest.bak.$(date +%Y%m%d-%H%M%S)"; sudo mkdir -p "$dest"; sudo cp -a "$theme_tmp/." "$dest/"; }
    rm -rf "$theme_tmp"
    conf=/etc/sddm.conf.d/vibeshell.conf
    ((DRY_RUN)) || { sudo mkdir -p /etc/sddm.conf.d; [[ -e $conf ]] && sudo cp -a "$conf" "$conf.bak.$(date +%Y%m%d-%H%M%S)"; printf '[Theme]\nCurrent=vibeshell\n' | sudo tee "$conf" >/dev/null; }
    log "sddm theme ready"
  else warn "sddm not installed"; fi
fi

# greetd
if ((INSTALL_GREETER)); then
  if ! has greetd || ! has niri; then warn "need greetd+niri"; else
    GREETER_SHELL=/usr/local/share/vibeshell/shell
    ((DRY_RUN)) || { sudo mkdir -p "$(dirname "$GREETER_SHELL")"; sudo rm -rf "$GREETER_SHELL"; sudo cp -r "$SRC/shell" "$GREETER_SHELL"; log "copied greeter shell"; }
    GKDIR=/etc/greetd; kdl_tmp=$(mktemp)
    cat >"$kdl_tmp" <<EOF
hotkey-overlay { skip-at-startup; }
spawn-at-startup "quickshell" "-p" "$GREETER_SHELL"
EOF
    if niri validate -c "$kdl_tmp" >/dev/null 2>&1; then
      ((DRY_RUN)) || { [[ -e $GKDIR/vibeshell-greeter.kdl ]] && sudo cp -a "$GKDIR/vibeshell-greeter.kdl" "$GKDIR/vibeshell-greeter.kdl.bak.$(date +%Y%m%d-%H%M%S)"; sudo cp "$kdl_tmp" "$GKDIR/vibeshell-greeter.kdl"; }
      ((DRY_RUN)) || { [[ -e $GKDIR/config.toml ]] && sudo cp -a "$GKDIR/config.toml" "$GKDIR/config.toml.bak.$(date +%Y%m%d-%H%M%S)"; printf '[terminal]\nvt=1\n\n[default_session]\ncommand="niri -c %s"\nuser="greeter"\n' "$GKDIR/vibeshell-greeter.kdl" | sudo tee "$GKDIR/config.toml" >/dev/null; }
      log "greetd configured"
      for dm in sddm gdm lightdm ly; do
        if systemctl is-enabled --quiet "$dm" 2>/dev/null && confirm "Disable $dm?"; then ((DRY_RUN)) || sudo systemctl disable "$dm" 2>/dev/null || true; fi
      done
      if confirm "Enable greetd?"; then ((DRY_RUN)) || sudo systemctl enable greetd 2>/dev/null || true; fi
    else err "greeter kdl invalid"; fi
    rm -f "$kdl_tmp"
  fi
fi

# supertap
if ((SUPER_TAP)); then
  if ! has keyd; then
    warn "keyd missing - install via pacman"; ((DRY_RUN)) || { sudo pacman -S --needed --noconfirm keyd || true; }
  fi
  if [[ -f /etc/keyd/default.conf ]] && ! confirm "Overwrite /etc/keyd/default.conf?"; then
    log "skip keyd"
  else
    ((DRY_RUN)) || { [[ -f /etc/keyd/default.conf ]] && sudo cp -a /etc/keyd/default.conf "/etc/keyd/default.conf.bak.$(date +%Y%m%d-%H%M%S)"; sudo mkdir -p /etc/keyd; sudo tee /etc/keyd/default.conf >/dev/null <<'EOF'
[ids]
*

[main]
leftmeta = overload(meta, f15)
EOF
    sudo systemctl enable --now keyd 2>/dev/null || true; }
    log "keyd configured"
  fi
fi

# plymouth
if ((STRIP_PLYMOUTH)); then
  if [[ -f /etc/default/grub ]]; then
    ((DRY_RUN)) || { backup /etc/default/grub; sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)splash \?/\1/; s/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)quiet \?/\1/; s/loglevel=[0-5]/loglevel=6/' /etc/default/grub; command -v grub-mkconfig >/dev/null && sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null || true; }
  fi
  if [[ -f /etc/mkinitcpio.conf ]] && grep -q plymouth /etc/mkinitcpio.conf; then
    ((DRY_RUN)) || { backup /etc/mkinitcpio.conf; sudo sed -i 's/ plymouth//g' /etc/mkinitcpio.conf; command -v mkinitcpio >/dev/null && sudo mkinitcpio -P >/dev/null || true; }
  fi
  if pacman -Qq plymouth >/dev/null 2>&1 && confirm "Remove plymouth package?"; then ((DRY_RUN)) || sudo pacman -Rns --noconfirm plymouth || true; fi
fi

# hints
if has systemctl; then
  inactive=(); for s in NetworkManager bluetooth upower; do systemctl is-active --quiet "$s" 2>/dev/null || inactive+=("$s"); done
  ((${#inactive[@]})) && warn "enable: sudo systemctl enable --now ${inactive[*]}"
fi
has brightnessctl && ! id -nG "$USER" 2>/dev/null | grep -qw video && warn "add video group: sudo usermod -aG video $USER"

log "Done. Try: quickshell -p $SRC/shell"
