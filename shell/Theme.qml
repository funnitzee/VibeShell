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
    readonly property int fontSize: Settings.data.font.size

    readonly property int barHeight: Settings.data.bar.height
    readonly property int gap: Settings.data.bar.gap
    readonly property int radius: Settings.data.bar.radius
    readonly property int borderWidth: Settings.data.bar.borderWidth

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
