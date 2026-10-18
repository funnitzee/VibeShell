pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Colors come from the active palette, sizes and font from Settings.
Singleton {
    id: root

    // Monochrome fallbacks, used until the palette file is loaded.
    property color bg: "#0a0a0a"
    property color surface: "#141414"
    property color border: "#2e2e2e"
    property color fg: "#e8e8e8"
    property color dim: "#8a8a8a"
    property color accent: "#ffffff"
    property color urgent: "#ffffff"

    readonly property string fontFamily: Settings.data.font.family

    // Global UI scale (Settings > "ui.scale"). Multiplies the font AND every
    // pixel constant (bar height, gaps, radius...), so the whole shell scales
    // together instead of only the text.
    readonly property real uiScale: Settings.data.ui.scale
    readonly property int fontSize: Math.round(Settings.data.font.size * uiScale)

    // Shell-wide animation toggle (Settings > "anim.enabled", :anim command).
    readonly property bool animations: Settings.data.anim.enabled

    // Palettes shipped with the shell, for the :theme command. Any file in
    // palette/ works too, via :set theme.palette <name>.
    readonly property var palettes: ["monochrome", "catppuccin-mocha", "tokyo-night", "rose-pine", "nord", "dracula", "kanagawa"]

    // Size of one character cell of the UI font. TUI-style components snap to it.
    readonly property real cellW: metrics.advanceWidth("M")
    readonly property real cellH: metrics.height

    readonly property int barHeight: Math.round(Settings.data.bar.height * uiScale)
    readonly property int gap: Math.round(Settings.data.bar.gap * uiScale)
    readonly property int radius: Math.round(Settings.data.bar.radius * uiScale)
    readonly property int borderWidth: Math.round(Settings.data.bar.borderWidth * uiScale)

    FontMetrics {
        id: metrics
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
    }

    function apply(p) {
        for (const k of ["bg", "surface", "border", "fg", "dim", "accent", "urgent"])
            if (p[k] !== undefined)
                root[k] = p[k];
    }

    FileView {
        path: Qt.resolvedUrl("palettes/" + Settings.data.theme.palette + ".json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.apply(JSON.parse(text()));
            } catch (e) {
                console.warn("VibeShell: invalid palette JSON:", e);
            }
        }
    }
}
