# VibeShell

A custom, terminal-flavoured desktop shell for [niri](https://github.com/YaLTeR/niri), built on [Quickshell](https://quickshell.org/) (QML).

> Work in progress. Currently only a skeleton with a monochrome theme.

## Goals

- Top bar with stats, media player, workspaces, clock, tray
- Everything configurable from a single settings file (gaps, radius, palette), later from a settings window
- Ready-made color palettes, swappable at runtime
- JetBrains Mono Nerd Font everywhere
- One-command installer for Arch / CachyOS

## Layout

```
shell/      Quickshell config (entry point: shell/shell.qml)
config/     Default settings and color palettes
```

## Status

See the commit history for what is already implemented.
