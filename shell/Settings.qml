pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shipped defaults merged with the user's settings.json.
// The user file lives in $VIBESHELL_CONFIG_DIR or ~/.config/vibeshell.
Singleton {
    id: root

    readonly property string userDir: Quickshell.env("VIBESHELL_CONFIG_DIR") || (Quickshell.env("HOME") + "/.config/vibeshell")

    // Loaded synchronously so that bindings never see an empty object.
    readonly property var defaults: parse(defaultsFile.text())
    property var user: ({})
    readonly property var data: merge(defaults, user)

    function merge(base, over) {
        const out = {};
        for (const k in base)
            out[k] = base[k];
        for (const k in over) {
            const isObj = v => v !== null && typeof v === "object" && !Array.isArray(v);
            out[k] = isObj(over[k]) && isObj(out[k]) ? merge(out[k], over[k]) : over[k];
        }
        return out;
    }

    function parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn("VibeShell: invalid JSON in settings:", e);
            return {};
        }
    }

    FileView {
        id: defaultsFile
        path: Qt.resolvedUrl("defaults/settings.json")
        blockLoading: true
    }

    FileView {
        id: userFile
        path: root.userDir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.user = root.parse(text())
        onLoadFailed: root.user = ({})
    }
}
