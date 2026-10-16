# VibeShell

A custom, terminal-flavoured desktop shell for [niri](https://github.com/YaLTeR/niri), built on [Quickshell](https://quickshell.org/) (QML).

> Work in progress. Currently a working skeleton with a monochrome theme.

## Install (Arch / CachyOS)

Download, read, run:

```sh
curl -fsSL https://raw.githubusercontent.com/funnitzee/VibeShell/main/install.sh -o install.sh
less install.sh
bash install.sh --niri
```

Or, if you trust this repo:

```sh
curl -fsSL https://raw.githubusercontent.com/funnitzee/VibeShell/main/install.sh | bash -s -- --niri
```

The installer asks before running `sudo pacman`, backs up every file it overwrites
(`<file>.bak.<timestamp>`), and can be re-run safely. Without `--niri` it only
writes `~/.config/niri/vibeshell.kdl` and tells you which `include` line to add.

Try it without restarting niri: `quickshell -p ~/.local/share/vibeshell/shell`

## Settings

User settings live in `~/.config/vibeshell/settings.json` and override
`shell/defaults/settings.json`. The shell reloads on every save.

```json
{
  "theme": { "palette": "monochrome" },
  "font": { "family": "JetBrainsMono Nerd Font", "size": 13 },
  "bar": { "height": 34, "gap": 8, "radius": 10, "borderWidth": 1 }
}
```

Palettes are JSON files in `shell/palettes/`.

## Development

`dev/run-nested.sh` runs the shell in a nested niri window with every XDG directory
redirected to `/tmp/vibeshell-dev`, so your real config is never touched.
`dev/run-nested.sh --shot 6` takes a screenshot after 6 seconds and quits.

## Layout

```
install.sh   Installer
shell/       Quickshell config (entry point: shell/shell.qml)
  bar/       Bar and its modules
  services/  niri workspaces, system stats
  palettes/  Color palettes
  defaults/  Shipped default settings
dev/         Nested niri sandbox
```

## Roadmap

- [x] Skeleton: settings, theme, top bar (workspaces, clock, media, stats)
- [x] Installer
- [ ] Settings window
- [ ] Color palettes, switchable at runtime
- [ ] Launcher, notifications, OSD, quick settings, lock screen, greeter
- [ ] App theming (kitty, GTK, VS Code, ...)
