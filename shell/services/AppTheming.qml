pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Regenerates app theme files (kitty, GTK, VS Code, spicetify) whenever the
// palette changes, so external apps match VibeShell. Files are written to
// $VIBESHELL_CONFIG_DIR/app-themes/ and the installer wires the include/import
// lines into each app's config (with backups). Set `theming.<app>` to false to
// skip an app. Trigger manually with `:theme` or over IPC:
//   quickshell ipc -p <shell dir> call theming regenerate
Singleton {
    id: root

    readonly property string outDir: Settings.userDir + "/app-themes"

    // Regenerate once the palette colours have been applied (Theme.apply runs
    // after its FileView loads, so a change here means the new colours are live).
    readonly property var _colors: [Theme.bg, Theme.surface, Theme.border, Theme.fg, Theme.dim, Theme.accent, Theme.urgent]
    on_ColorsChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 50
        onTriggered: root.regenerate()
    }

    Component.onCompleted: regenerate()

    IpcHandler {
        target: "theming"

        function regenerate(): void {
            root.regenerate();
        }
        function dir(): string {
            return root.outDir;
        }
    }

    function regenerate() {
        const p = Settings.data.theme.palette;
        const enabled = Settings.data.theming;
        if (enabled.kitty)
            kittyFile.setText(kittyConf(p));
        if (enabled.gtk)
            gtkFile.setText(gtkCss(p));
        if (enabled.vscode) {
            vscodeThemeFile.setText(vscodeTheme(p));
            vscodePkgFile.setText(vscodePackage(p));
        }
        if (enabled.spicetify) {
            spicetifyColorFile.setText(spicetifyColorIni(p));
            spicetifyCssFile.setText(spicetifyUserCss(p));
        }
        if (enabled.sddm)
            sddmConfFile.setText(sddmThemeConf(p));
        if (enabled.matugen)
            syncMatugen();
    }

    // theme.conf for the VibeShell SDDM theme. The installer copies this into
    // /usr/share/sddm/themes/vibeshell (with --sddm), so the login screen can
    // follow the palette too.
    function sddmThemeConf(p) {
        const c = {
            bg: String(Theme.bg),
            fg: String(Theme.fg),
            dim: String(Theme.dim),
            border: String(Theme.border),
            accent: String(Theme.accent),
            urgent: String(Theme.urgent)
        };
        return `[General]
# VibeShell SDDM theme: ${p} (generated, do not edit)
bg=${c.bg}
fg=${c.fg}
dim=${c.dim}
border=${c.border}
accent=${c.accent}
urgent=${c.urgent}
font=${Settings.data.font.family}
`;
    }

    // Push the current accent into matugen, so every matugen-managed app
    // (waybar, rofi, qt, gtk...) follows the shell palette.
    function syncMatugen() {
        if (!matugenProbe.available)
            return;
        matugenSync.command = ["matugen", "color", "hex", String(Theme.accent)];
        matugenSync.running = true;
    }

    Process {
        id: matugenProbe
        command: ["sh", "-c", "command -v matugen"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: matugenProbe.available = text.trim() !== ""
        }
        property bool available: false
    }

    Process {
        id: matugenSync
    }

    // ---- colour helpers -------------------------------------------------

    function hexToRgb(hex) {
        const h = String(hex).replace("#", "");
        return {
            r: parseInt(h.substring(0, 2), 16),
            g: parseInt(h.substring(2, 4), 16),
            b: parseInt(h.substring(4, 6), 16)
        };
    }

    function rgbToHex(r, g, b) {
        const c = v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0");
        return "#" + c(r) + c(g) + c(b);
    }

    function rgbToHsl(r, g, b) {
        r /= 255;
        g /= 255;
        b /= 255;
        const max = Math.max(r, g, b), min = Math.min(r, g, b);
        let h, s;
        const l = (max + min) / 2;
        if (max === min) {
            h = s = 0;
        } else {
            const d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            switch (max) {
            case r:
                h = (g - b) / d + (g < b ? 6 : 0);
                break;
            case g:
                h = (b - r) / d + 2;
                break;
            case b:
                h = (r - g) / d + 4;
                break;
            }
            h /= 6;
        }
        return {
            h: h * 360,
            s,
            l
        };
    }

    function hslToRgb(h, s, l) {
        h /= 360;
        let r, g, b;
        if (s === 0) {
            r = g = b = l;
        } else {
            const hue2rgb = (p, q, t) => {
                if (t < 0)
                    t += 1;
                if (t > 1)
                    t -= 1;
                if (t < 1 / 6)
                    return p + (q - p) * 6 * t;
                if (t < 1 / 2)
                    return q;
                if (t < 2 / 3)
                    return p + (q - p) * (2 / 3 - t) * 6;
                return p;
            };
            const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            const p = 2 * l - q;
            r = hue2rgb(p, q, h + 1 / 3);
            g = hue2rgb(p, q, h);
            b = hue2rgb(p, q, h - 1 / 3);
        }
        return {
            r: r * 255,
            g: g * 255,
            b: b * 255
        };
    }

    // Shift the hue of `hex` by `dh` degrees and lighten/darken by `dl`.
    function tint(hex, dh, dl) {
        const c = hexToRgb(hex);
        const hsl = rgbToHsl(c.r, c.g, c.b);
        const rgb = hslToRgb((hsl.h + dh + 360) % 360, hsl.s, Math.max(0, Math.min(1, hsl.l + dl)));
        return rgbToHex(rgb.r, rgb.g, rgb.b);
    }

    // Derive the 16 ANSI colours from the palette's 7 semantic ones.
    function ansi() {
        const bg = String(Theme.bg), fg = String(Theme.fg), dim = String(Theme.dim), accent = String(Theme.accent), urgent = String(Theme.urgent);
        // Coloured slots are hue-shifted off the accent; desaturated palettes
        // (monochrome) just vary in lightness instead of hue.
        const sat = rgbToHsl(hexToRgb(accent).r, hexToRgb(accent).g, hexToRgb(accent).b).s;
        const pick = (dh, dl) => sat < 0.08 ? tint(fg, 0, dl) : tint(accent, dh, dl);
        return {
            black: bg,
            red: urgent,
            green: pick(120, 0),
            yellow: pick(60, 0),
            blue: accent,
            magenta: pick(-60, 0),
            cyan: pick(180, 0),
            white: fg,
            brightBlack: dim,
            brightRed: tint(urgent, 0, 0.12),
            brightGreen: pick(120, 0.12),
            brightYellow: pick(60, 0.12),
            brightBlue: tint(accent, 0, 0.12),
            brightMagenta: pick(-60, 0.12),
            brightCyan: pick(180, 0.12),
            brightWhite: tint(fg, 0, 0.1)
        };
    }

    // ---- generators -----------------------------------------------------

    function kittyConf(p) {
        const a = ansi();
        const c = {
            bg: String(Theme.bg),
            fg: String(Theme.fg),
            surface: String(Theme.surface),
            border: String(Theme.border),
            dim: String(Theme.dim),
            accent: String(Theme.accent),
            urgent: String(Theme.urgent)
        };
        // Full kitty.conf, not just colours: font, padding, cursor and
        // scrollback come from the shell settings so kitty looks right
        // straight after install.
        return `# VibeShell kitty config: ${p} (generated, do not edit)

# font
font_family      ${Settings.data.font.family}
bold_font        auto
italic_font      auto
font_size        ${Settings.data.font.size}
# cell/padding in the same rhythm as the shell UI
window_padding_width ${Math.round(Settings.data.font.size * 0.6)}

# cursor
cursor_shape             block
cursor_blink_interval    ${Theme.animations ? 0.5 : 0}
cursor_stop_blinking_after 15.0
shell_integration        enabled

# window
remember_window_size  yes
initial_window_width  92c
initial_window_height 28c
window_margin_width   4
confirm_os_window_close 0
enable_audio_bell     no

# scrollback
scrollback_lines      10000
scrollback_pager_history_size 64

# colors
foreground ${c.fg}
background ${c.bg}
cursor ${c.accent}
cursor_text_color ${c.bg}
selection_foreground ${c.fg}
selection_background ${c.surface}
url_color ${c.accent}
active_border_color ${c.accent}
inactive_border_color ${c.border}
bell_border_color ${c.urgent}
color0 ${a.black}
color1 ${a.red}
color2 ${a.green}
color3 ${a.yellow}
color4 ${a.blue}
color5 ${a.magenta}
color6 ${a.cyan}
color7 ${a.white}
color8 ${a.brightBlack}
color9 ${a.brightRed}
color10 ${a.brightGreen}
color11 ${a.brightYellow}
color12 ${a.brightBlue}
color13 ${a.brightMagenta}
color14 ${a.brightCyan}
color15 ${a.brightWhite}
`;
    }

    function gtkCss(p) {
        const c = {
            bg: String(Theme.bg),
            fg: String(Theme.fg),
            surface: String(Theme.surface),
            border: String(Theme.border),
            dim: String(Theme.dim),
            accent: String(Theme.accent),
            urgent: String(Theme.urgent)
        };
        return `/* VibeShell GTK theme: ${p} (generated, do not edit) */
@define-color theme_bg_color ${c.bg};
@define-color theme_fg_color ${c.fg};
@define-color theme_base_color ${c.surface};
@define-color theme_text_color ${c.fg};
@define-color theme_selected_bg_color ${c.accent};
@define-color theme_selected_fg_color ${c.bg};
@define-color theme_unfocused_bg_color ${c.bg};
@define-color theme_unfocused_fg_color ${c.dim};
@define-color theme_error_color ${c.urgent};
@define-color borders ${c.border};
`;
    }

    function vscodeTheme(p) {
        const c = {
            bg: String(Theme.bg),
            fg: String(Theme.fg),
            surface: String(Theme.surface),
            border: String(Theme.border),
            dim: String(Theme.dim),
            accent: String(Theme.accent),
            urgent: String(Theme.urgent)
        };
        const theme = {
            name: `VibeShell ${p}`,
            type: "dark",
            colors: {
                "editor.background": c.bg,
                "editor.foreground": c.fg,
                "sideBar.background": c.surface,
                "sideBar.foreground": c.fg,
                "activityBar.background": c.bg,
                "activityBar.foreground": c.fg,
                "titleBar.activeBackground": c.surface,
                "titleBar.activeForeground": c.fg,
                "statusBar.background": c.bg,
                "statusBar.foreground": c.fg,
                "focusBorder": c.accent,
                "selection.background": c.dim,
                "terminal.background": c.bg,
                "terminal.foreground": c.fg
            },
            tokenColors: [
                {
                    scope: ["comment"],
                    settings: {
                        foreground: c.dim
                    }
                },
                {
                    scope: ["keyword", "storage"],
                    settings: {
                        foreground: c.accent
                    }
                },
                {
                    scope: ["string"],
                    settings: {
                        foreground: c.urgent
                    }
                }
            ]
        };
        return JSON.stringify(theme, null, 2) + "\n";
    }

    function vscodePackage(p) {
        const pkg = {
            name: "vibeshell-theme",
            displayName: `VibeShell ${p}`,
            description: "Generated by VibeShell",
            version: "0.0.1",
            publisher: "vibeshell",
            engines: {
                vscode: "^1.60.0"
            },
            categories: ["Themes"],
            contributes: {
                themes: [
                    {
                        label: `VibeShell ${p}`,
                        uiTheme: "vs-dark",
                        path: "./theme.json"
                    }
                ]
            }
        };
        return JSON.stringify(pkg, null, 2) + "\n";
    }

    function spicetifyColorIni(p) {
        const c = {
            bg: String(Theme.bg).replace("#", ""),
            fg: String(Theme.fg).replace("#", ""),
            surface: String(Theme.surface).replace("#", ""),
            border: String(Theme.border).replace("#", ""),
            dim: String(Theme.dim).replace("#", ""),
            accent: String(Theme.accent).replace("#", ""),
            urgent: String(Theme.urgent).replace("#", "")
        };
        return `# VibeShell spicetify theme: ${p} (generated, do not edit)
[Base]
main             = ${c.bg}
sidebar          = ${c.bg}
player           = ${c.bg}
card             = ${c.surface}
shadow           = 000000
selected-row     = ${c.fg}
button           = ${c.accent}
button-active    = ${c.accent}
button-disabled  = ${c.dim}
tab-active       = ${c.surface}
notification     = ${c.bg}
misc             = ${c.dim}
text             = ${c.fg}
subtext          = ${c.dim}
main-secondary   = ${c.surface}
highlight        = ${c.accent}
highlight-hover  = ${c.accent}
highlight-active = ${c.accent}
`;
    }

    function spicetifyUserCss(p) {
        return `/* VibeShell spicetify theme: ${p} (generated, do not edit) */
:root {
    --vibeshell-bg: ${String(Theme.bg)};
    --vibeshell-fg: ${String(Theme.fg)};
    --vibeshell-accent: ${String(Theme.accent)};
}
`;
    }

    // ---- output files ---------------------------------------------------

    FileView {
        id: kittyFile
        path: root.outDir + "/kitty/kitty-theme.conf"
        onSaveFailed: error => console.warn("VibeShell: could not write kitty theme:", error)
    }

    FileView {
        id: gtkFile
        path: root.outDir + "/gtk/gtk.css"
        onSaveFailed: error => console.warn("VibeShell: could not write GTK theme:", error)
    }

    FileView {
        id: vscodeThemeFile
        path: root.outDir + "/vscode/theme.json"
        onSaveFailed: error => console.warn("VibeShell: could not write VS Code theme:", error)
    }

    FileView {
        id: vscodePkgFile
        path: root.outDir + "/vscode/package.json"
        onSaveFailed: error => console.warn("VibeShell: could not write VS Code package.json:", error)
    }

    FileView {
        id: spicetifyColorFile
        path: root.outDir + "/spicetify/color.ini"
        onSaveFailed: error => console.warn("VibeShell: could not write spicetify color.ini:", error)
    }

    FileView {
        id: spicetifyCssFile
        path: root.outDir + "/spicetify/user.css"
        onSaveFailed: error => console.warn("VibeShell: could not write spicetify user.css:", error)
    }

    FileView {
        id: sddmConfFile
        path: root.outDir + "/sddm/theme.conf"
        onSaveFailed: error => console.warn("VibeShell: could not write SDDM theme.conf:", error)
    }
}
